#!/usr/bin/env python3
"""Field-conditions evaluation: how the scanner's decisions hold up when test photos are degraded the way a phone camera
sees plants on the preserve's trails: dim understory, dusk + noise, flashlight at night, backlight, dappled canopy light,
overexposure, motion and focus blur, a small far-away subject, a tight zoom, white-balance casts, JPEG, rotation, low res.

Every number comes from real held-out test images (observer-level split), degraded deterministically (seed per image).
Decision logic mirrors ScanDecision.decideRaw: Tier 1 confirm needs p >= per-class floor, margin >= 0.30, normalised
entropy <= 0.45; "possible" needs p >= possibleMinProbability; not_plant >= 0.5 means "no plant".

Usage: model/.venv/bin/python -I model/field_eval.py --version v3 [--n 1500] [--ensemble v2]
Writes model/eval/field_<version>.json
"""
import argparse, json, math, random
import numpy as np, torch, timm
from PIL import Image, ImageFilter, ImageEnhance
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa: E402

def load(version, device):
    ck = torch.load(MODEL / "checkpoints" / f"{version}_best.pt", map_location="cpu", weights_only=False)
    ev = json.load(open(EVAL / f"{version}_eval.json"))
    m = timm.create_model(ck["arch"], pretrained=False, num_classes=len(ck["labels"])); m.load_state_dict(ck["state_dict"]); m.eval().to(device)
    return m, ck["labels"], ck["size"], ev["temperature"]

# ---- degradations (PIL in, PIL out; rng per image so results are reproducible) ----------------------------------
def _np(img): return np.asarray(img).astype(np.float32) / 255.0
def _pil(a): return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))

def clean(img, rng): return img
def dim(img, rng):           # shaded understory: -1.5 EV, slightly lifted gamma
    return _pil((_np(img) * 0.42) ** 1.25)
def dusk_noisy(img, rng):    # near dusk: -2.5 EV, sensor noise, mild blur
    a = _np(img.filter(ImageFilter.GaussianBlur(0.8))) * 0.2
    return _pil(a + rng.normal(0, 0.035, a.shape))
def torch_lit(img, rng):     # phone flashlight at night: dark edges, bright warm centre
    a = _np(img); h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]; r = np.sqrt(((yy - h / 2) / h) ** 2 + ((xx - w / 2) / w) ** 2)
    spot = np.clip(1.35 - 2.6 * r, 0.12, 1.35)[..., None]
    a = a * spot * np.array([1.08, 1.0, 0.82]); return _pil(a + rng.normal(0, 0.02, a.shape))
def backlit(img, rng):       # bright sky behind the leaves: haze + strong top gradient, lower contrast
    a = _np(img); h = a.shape[0]
    grad = np.linspace(0.55, 0.0, h)[:, None, None]
    a = a * 0.75 + 0.15 + grad; return _pil(a)
def overexposed(img, rng):   # harsh sun: +1.3 EV with clipping
    return _pil(_np(img) * 2.4 - 0.15)
def dappled(img, rng):       # sun flecks through the canopy: low-frequency multiplicative mask 0.3..1.45
    a = _np(img); h, w = a.shape[:2]
    g = rng.uniform(0, 1, (5, 5)).astype(np.float32)
    mask = np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)).astype(np.float32) / 255.0
    mask = 0.3 + 1.15 * mask ** 1.5
    return _pil(a * mask[..., None])
def motion_blur(img, rng):   # hand shake: 13 px line kernel at a random angle
    a = _np(img); k = 13; ang = rng.uniform(0, math.pi)
    ker = np.zeros((k, k), np.float32); c = k // 2
    for t in np.linspace(-c, c, 4 * k):
        ker[int(round(c + t * math.sin(ang))), int(round(c + t * math.cos(ang)))] = 1
    ker /= ker.sum()
    import torch.nn.functional as F
    x = torch.from_numpy(a).permute(2, 0, 1)[None]; kk = torch.from_numpy(ker)[None, None].repeat(3, 1, 1, 1)
    y = F.conv2d(F.pad(x, (c, c, c, c), mode="reflect"), kk, groups=3)[0].permute(1, 2, 0).numpy(); return _pil(y)
def defocus(img, rng): return img.filter(ImageFilter.GaussianBlur(2.6))
def far(img, rng):           # subject at 42% of the frame on a blurred darker copy of its own surroundings
    w, h = img.size
    bg = img.resize((w * 2, h * 2), Image.BILINEAR).crop((w // 2, h // 2, w // 2 + w, h // 2 + h)).filter(ImageFilter.GaussianBlur(6))
    bg = ImageEnhance.Brightness(bg).enhance(0.7)
    s = 0.42; sm = img.resize((max(8, int(w * s)), max(8, int(h * s))), Image.LANCZOS)
    bg.paste(sm, (int((w - sm.size[0]) * rng.uniform(0.3, 0.7)), int((h - sm.size[1]) * rng.uniform(0.3, 0.7)))); return bg
def zoomed(img, rng):        # too close: centre 55 %
    w, h = img.size; cw, ch = int(w * 0.55), int(h * 0.55)
    return img.crop(((w - cw) // 2, (h - ch) // 2, (w - cw) // 2 + cw, (h - ch) // 2 + ch)).resize((w, h), Image.BILINEAR)
def cool_cast(img, rng): return _pil(_np(img) * np.array([0.82, 0.95, 1.18]))
def warm_cast(img, rng): return _pil(_np(img) * np.array([1.18, 1.0, 0.78]))
def jpeg30(img, rng):
    import io; b = io.BytesIO(); img.save(b, "JPEG", quality=28); b.seek(0); return Image.open(b).convert("RGB")
def rot90(img, rng): return img.transpose(Image.ROTATE_90)
def lowres(img, rng):
    w, h = img.size; return img.resize((96, int(96 * h / w)), Image.BILINEAR).resize((w, h), Image.BILINEAR)

CONDITIONS = [clean, dim, dusk_noisy, torch_lit, backlit, overexposed, dappled, motion_blur, defocus, far, zoomed, cool_cast, warm_cast, jpeg30, rot90, lowres]

def entropy_norm(p):
    p = p[p > 0]; return float(-(p * np.log(p)).sum() / math.log(max(len(p), 10)))

def decide(p, labels, tiers, th):
    """Returns 'confirmed' | 'possible' | 'native' | 'noplant' | 'rescan' like ScanDecision.decideRaw."""
    order = np.argsort(-p); top = order[0]; tl = labels[top]; pt = float(p[top]); margin = pt - float(p[order[1]])
    if tl == "not_plant" and pt >= th["notPlantMinProbability"]: return "noplant"
    inv = [labels[i] for i in order[:3] if tiers[labels[i]] in ("tier1", "tier2") and p[i] >= th["possibleMinProbability"]]
    tier = tiers[tl]
    if tier == "tier1":
        if pt >= th["perClassConfirmMin"].get(tl, th["confirmMinProbability"]) and margin >= th["confirmMinMargin"] and entropy_norm(p / p.sum()) <= th["maxEntropyForConfirm"]: return "confirmed"
        if pt >= th["possibleMinProbability"]: return "possible"
        return "rescan"
    if tier == "tier2": return "possible" if pt >= th["possibleMinProbability"] else "rescan"
    if inv and pt < th["nativeMinProbability"]: return "possible"
    if pt >= th["nativeMinProbability"]: return "native"
    return "possible" if inv else "rescan"

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--version", default="v3"); ap.add_argument("--ensemble", default=None, help="second checkpoint averaged on the still")
    ap.add_argument("--n", type=int, default=1500); ap.add_argument("--thresholds", default=None); args = ap.parse_args()
    device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
    model, labels, size, T = load(args.version, device)
    second = load(args.ensemble, device) if args.ensemble else None
    _, tiers, _ = load_classes(); tiers = {l: tiers.get(l, "other") for l in labels}
    th = json.load(open(args.thresholds or (EVAL / f"{args.version}_thresholds.json")))
    tst = np.load(EVAL / f"{args.version}_logits_test.npz", allow_pickle=True)
    paths, ys = list(tst["paths"]), list(tst["y"])
    # even subsample across classes, deterministic
    rng0 = random.Random(7); by = {}
    for p, y in zip(paths, ys): by.setdefault(int(y), []).append(p)
    per = max(2, args.n // len(by)); sel = []
    for y in sorted(by):
        ps = by[y][:]; rng0.shuffle(ps); sel += [(p, y) for p in ps[:per]]
    sel = sel[: args.n]
    from torchvision.transforms import v2 as TV
    prep = TV.Compose([TV.Resize(int(size * 1.14), antialias=True), TV.CenterCrop(size), TV.ToImage(), TV.ToDtype(torch.float32, scale=True), TV.Normalize(MEAN, STD)])
    def probs(imgs):
        x = torch.stack([prep(i) for i in imgs]).to(device)
        with torch.no_grad():
            p = torch.softmax(model(x).float() / T, 1)
            if second:
                m2, l2, s2, T2 = second
                assert l2 == labels
                x2 = x if s2 == size else torch.nn.functional.interpolate(x, size=(s2, s2), mode="bilinear", antialias=True)
                p = (p + torch.softmax(m2(x2).float() / T2, 1)) / 2
        return p.cpu().numpy()
    results = {}
    for cond in CONDITIONS:
        P = []; Y = []
        batch = []
        for i, (p, y) in enumerate(sel):
            rng = np.random.default_rng(1000 + i)
            try: img = Image.open(p).convert("RGB")
            except Exception: continue
            batch.append(cond(img, rng)); Y.append(y)
            if len(batch) == 64: P.append(probs(batch)); batch = []
        if batch: P.append(probs(batch))
        P = np.concatenate(P); Y = np.array(Y)
        pred = P.argmax(1); dec = [decide(P[i], labels, tiers, th) for i in range(len(Y))]
        t = np.array([tiers[labels[y]] for y in Y]); lab = np.array([labels[y] for y in Y]); dec = np.array(dec)
        is_t1 = t == "tier1"; conf = dec == "confirmed"; flagged = (dec == "confirmed") | (dec == "possible")
        plant = lab != "not_plant"
        r = {"n": int(len(Y)), "top1": round(float((pred == Y).mean()), 4),
             "tier1_top1": round(float((pred[is_t1] == Y[is_t1]).mean()), 4),
             "confirm_precision": round(float((pred[conf] == Y[conf]).mean()), 4) if conf.any() else None,
             "confirm_coverage_tier1": round(float(conf[is_t1].mean()), 4),
             "tier1_flagged": round(float(flagged[is_t1].mean()), 4),
             "tier2_flagged": round(float(flagged[t == "tier2"].mean()), 4),
             "native_flagged_as_invasive": round(float(flagged[t == "native"].mean()), 4),
             "other_plant_flagged": round(float(flagged[lab == "other_plant"].mean()), 4),
             "not_plant_flagged": round(float(flagged[lab == "not_plant"].mean()), 4),
             "plant_registers_as_plant": round(float((dec[plant] != "noplant").mean()), 4),
             "plant_rescan": round(float((dec[plant] == "rescan").mean()), 4)}
        results[cond.__name__] = r
        print(f"{cond.__name__:12s} top1 {r['top1']:.3f} t1 {r['tier1_top1']:.3f} confP {r['confirm_precision']} cov {r['confirm_coverage_tier1']:.3f} t1flag {r['tier1_flagged']:.3f} natFP {r['native_flagged_as_invasive']:.3f} othFP {r['other_plant_flagged']:.3f} reg {r['plant_registers_as_plant']:.3f} rescan {r['plant_rescan']:.3f}", flush=True)
    hard = [k for k in results if k != "clean"]
    summary = {k: round(float(np.mean([results[c][k] for c in hard if results[c][k] is not None])), 4) for k in ["top1", "tier1_top1", "confirm_precision", "confirm_coverage_tier1", "tier1_flagged", "native_flagged_as_invasive", "other_plant_flagged", "plant_registers_as_plant", "plant_rescan"]}
    out = {"version": args.version, "ensemble": args.ensemble, "images": len(sel), "thresholds": str(args.thresholds or f"{args.version}_thresholds.json"),
           "conditions": results, "mean_over_degraded": summary, "note": "Deterministic degradations of held-out test images; see docstring."}
    name = f"field_{args.version}" + (f"+{args.ensemble}" if args.ensemble else "")
    json.dump(out, open(EVAL / f"{name}.json", "w"), indent=1); print("mean over degraded:", summary); print("wrote", EVAL / f"{name}.json")

if __name__ == "__main__":
    main()
