#!/usr/bin/env python3
"""Head-to-head on the SAME images: both models on the newer version's test split, with each model's own
calibration, thresholds and centroids. Usage: model/.venv/bin/python -I model/compare_models.py v2 v3"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa: E402
import numpy as np, torch, timm
from torch.utils.data import DataLoader

def softmax(z):
    z = z - z.max(1, keepdims=True); e = np.exp(z); return e / e.sum(1, keepdims=True)

def run(version, paths, device):
    ck = torch.load(MODEL / "checkpoints" / f"{version}_best.pt", map_location="cpu", weights_only=False)
    labels, size = ck["labels"], ck["size"]
    model = timm.create_model(ck["arch"], pretrained=False, num_classes=len(labels)); model.load_state_dict(ck["state_dict"]); model.eval().to(device)
    items = [{"path": p, "label_idx": 0} for p in paths]
    dl = DataLoader(ImageListDataset(items, make_transforms(size, False)), batch_size=128, num_workers=4)
    L, E = [], []
    with torch.no_grad():
        for x, _ in dl:
            x = x.to(device); f = model.forward_head(model.forward_features(x), pre_logits=True)
            L.append(model.get_classifier()(f).float().cpu()); E.append(torch.nn.functional.normalize(f, dim=1).float().cpu())
    return labels, torch.cat(L).numpy(), torch.cat(E).numpy()

def main():
    a, b = sys.argv[1], sys.argv[2]
    device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
    te = np.load(EVAL / f"{b}_logits_test.npz"); paths = [str(p) for p in te["paths"]]
    truth = {str(p): int(y) for p, y in zip(te["paths"], te["y"])}
    split_b = json.load(open(MODEL / "runs" / f"{b}_split.json")); labels_b, tiers = split_b["labels"], split_b["tiers"]
    y_names = [labels_b[truth[p]] for p in paths]
    is_cult = np.array(["/cult_" in p for p in paths])
    inv_names = {l for l in labels_b if tiers[l] in ("tier1", "tier2")}
    t1_names = {l for l in labels_b if tiers[l] == "tier1"}
    out = {}
    keep = {}
    for v in (a, b):
        labels, L, E = run(v, paths, device)
        ev = json.load(open(EVAL / f"{v}_eval.json")); T = ev["temperature"]; thr = ev["confirm"]["threshold"]; per = ev["confirm"]["perClass"]; margin = ev["confirm"]["margin"]
        cen = json.load(open(EVAL / f"{v}_centroids.json"))["classes"]
        C = np.array([cen[l]["centroid"] for l in labels], dtype=np.float32); floors = np.array([cen[l]["minCosine"] for l in labels])
        P = softmax(L / T); top = P.argmax(1); conf = P.max(1); srt = np.sort(P, 1); mg = srt[:, -1] - srt[:, -2]
        pred = np.array([labels[t] for t in top]); yn = np.array(y_names)
        top3 = np.argsort(-P, 1)[:, :3]; in3 = np.array([yn[i] in {labels[k] for k in top3[i]} for i in range(len(yn))])
        sim = (E @ C.T)[np.arange(len(top)), top]; floor = floors[top]
        thr_vec = np.array([per.get(labels[t], thr) for t in top])
        is_t1_pred = np.array([l in t1_names for l in pred]); is_inv_pred = np.array([l in inv_names for l in pred])
        confirmed = is_t1_pred & (conf >= thr_vec) & (mg >= margin) & (sim >= floor)
        possible = is_inv_pred & (conf >= 0.45) & ~(sim < floor - 0.05)
        flagged = confirmed | possible
        correct = pred == yn
        def grp(mask): return {"n": int(mask.sum()), "top1": float(correct[mask].mean()) if mask.any() else None, "top3": float(in3[mask].mean()) if mask.any() else None}
        tier_of = np.array([tiers.get(n, "other") for n in yn])
        r = {"top1_all": float(correct.mean()), "top3_all": float(in3.mean()),
             "tier1": grp(tier_of == "tier1"), "tier2": grp(tier_of == "tier2"), "native": grp(tier_of == "native"),
             "other_plant": grp(yn == "other_plant"), "not_plant": grp(yn == "not_plant"), "cultivated": grp(is_cult)}
        true_inv = np.array([n in inv_names for n in yn]); true_t1 = np.array([n in t1_names for n in yn])
        r["confirm_precision"] = float((confirmed & correct).sum() / max(confirmed.sum(), 1))
        r["confirm_coverage_tier1"] = float((confirmed & true_t1 & correct).sum() / max(true_t1.sum(), 1))
        r["confirm_n"] = int(confirmed.sum())
        for name, mask in (("natives", tier_of == "native"), ("other_plant_wild", (yn == "other_plant") & ~is_cult), ("cultivated", is_cult), ("not_plant", yn == "not_plant")):
            r[f"flagged_{name}"] = float(flagged[mask].mean()) if mask.any() else None
            r[f"confirmed_{name}"] = float(confirmed[mask].mean()) if mask.any() else None
        r["true_invasives_flagged"] = float(flagged[true_inv].mean())
        out[v] = r
        keep[v] = dict(labels=labels, P=P, E=E, thr=thr, per=per, margin=margin, C=C, floors=floors)
        print(v, json.dumps(r, indent=None), flush=True)
    # ensemble: average of the two calibrated distributions (aligned by label), gate/thresholds from the newer model
    kb, ka = keep[b], keep[a]
    idx = [ka["labels"].index(l) for l in kb["labels"]]
    P = (kb["P"] + ka["P"][:, idx]) / 2
    labels = kb["labels"]; top = P.argmax(1); conf = P.max(1); srt = np.sort(P, 1); mg = srt[:, -1] - srt[:, -2]
    pred = np.array([labels[t] for t in top]); yn = np.array(y_names)
    sim = (kb["E"] @ kb["C"].T)[np.arange(len(top)), top]; floor = kb["floors"][top]
    thr_vec = np.array([kb["per"].get(labels[t], kb["thr"]) for t in top])
    is_t1_pred = np.array([l in t1_names for l in pred]); is_inv_pred = np.array([l in inv_names for l in pred])
    confirmed = is_t1_pred & (conf >= thr_vec) & (mg >= kb["margin"]) & (sim >= floor)
    possible = is_inv_pred & (conf >= 0.45) & ~(sim < floor - 0.05)
    flagged = confirmed | possible; correct = pred == yn
    top3 = np.argsort(-P, 1)[:, :3]; in3 = np.array([yn[i] in {labels[k] for k in top3[i]} for i in range(len(yn))])
    tier_of = np.array([tiers.get(n, "other") for n in yn])
    def grp(mask): return {"n": int(mask.sum()), "top1": float(correct[mask].mean()) if mask.any() else None, "top3": float(in3[mask].mean()) if mask.any() else None}
    true_inv = np.array([n in inv_names for n in yn]); true_t1 = np.array([n in t1_names for n in yn])
    r = {"top1_all": float(correct.mean()), "top3_all": float(in3.mean()), "ece_primary": float(json.load(open(EVAL / f"{b}_eval.json"))["ece_test"]), "confirm_threshold": kb["thr"], "tier1": grp(tier_of == "tier1"), "tier2": grp(tier_of == "tier2"), "native": grp(tier_of == "native"),
         "other_plant": grp(yn == "other_plant"), "not_plant": grp(yn == "not_plant"),
         "confirm_precision": float((confirmed & correct).sum() / max(confirmed.sum(), 1)), "confirm_coverage_tier1": float((confirmed & true_t1 & correct).sum() / max(true_t1.sum(), 1)), "confirm_n": int(confirmed.sum())}
    for name, mask in (("natives", tier_of == "native"), ("other_plant_wild", (yn == "other_plant") & ~is_cult), ("not_plant", yn == "not_plant")):
        r[f"flagged_{name}"] = float(flagged[mask].mean()) if mask.any() else None
    r["true_invasives_flagged"] = float(flagged[true_inv].mean())
    out["ensemble"] = r
    print("ensemble", json.dumps(r, indent=None), flush=True)
    json.dump({"testSet": f"{b} test split, {len(paths)} images", "results": out}, open(EVAL / f"compare_{a}_{b}.json", "w"), indent=1)
    if "--write-card" in sys.argv:
        e = out["ensemble"]; evb = json.load(open(EVAL / f"{b}_eval.json"))
        sa = json.load(open(MODEL / "runs" / f"{a}_split.json")); sb = json.load(open(MODEL / "runs" / f"{b}_split.json"))
        arch = {"efficientnet_b0": "EfficientNet-B0", "efficientnet_b2": "EfficientNet-B2", "mobilenetv3_large_100": "MobileNetV3-Large"}
        desc = lambda sp: f"{arch.get(sp['arch'], sp['arch'])}, {sp['size']} px"
        field = {}
        for name in (f"field_{b}+{a}", f"field_{b}", f"field_{a}", "field_v3+v2"):
            fp = EVAL / f"{name}.json"
            if fp.exists(): field[name] = json.load(open(fp))
        before = EVAL / "local_natives_before_v3+v2.json"
        before = json.load(open(before)) if before.exists() else None
        card = {"status": "evaluated", "modelVersion": f"{b}+{a} ensemble", "evaluatedOn": __import__("time").strftime("%Y-%m-%d"),
                "testObservations": len({os.path.basename(p).split("_")[0] for p in paths}),
                "tier1": {"classes": sum(1 for l in labels if tiers[l] == "tier1"), "testImages": e["tier1"]["n"], "top1": e["tier1"]["top1"], "top3": e["tier1"]["top3"], "precisionAtConfirm": e["confirm_precision"], "coverageAtConfirm": e["confirm_coverage_tier1"], "confirmThreshold": e["confirm_threshold"]},
                "tier2": {"classes": sum(1 for l in labels if tiers[l] == "tier2"), "testImages": e["tier2"]["n"], "top1": e["tier2"]["top1"], "top3": e["tier2"]["top3"], "precisionAtConfirm": None, "coverageAtConfirm": None, "confirmThreshold": None},
                "ece": e["ece_primary"], "notPlantRejectRate": e["not_plant"]["top1"], "hardestConfusions": evb["hardestConfusions"][:5],
                "fieldAccuracy": None, "fieldPhotos": None,
                "dataSource": "iNaturalist research-grade photos (CC0/CC-BY/CC-BY-NC), observer-level split; two models averaged on the captured still",
                "notes": "Held-out accuracy on iNaturalist photos. Field accuracy will be lower and is not measured yet."}
        json.dump(card, open(RES / "model_card.json", "w"), indent=1)
        pct = lambda v: "n/a" if v is None else f"{100*v:.1f}%"
        L = [f"# Model card: InvasiveClassifier {b} + {a} ensemble", "",
             f"Evaluated {card['evaluatedOn']} on the {b} test split ({len(paths)} images, {card['testObservations']} observations, observers disjoint from training). Every number comes from `model/eval/compare_{a}_{b}.json` (`model/compare_models.py`), `model/eval/{b}_eval.json` and `model/eval/{a}_eval.json`.", "",
             "## What runs on the phone",
             f"- Live view: {b} alone ({desc(sb)}) at about 4 frames per second, on the whole frame and on the salient region.",
             f"- Captured still: {b} ({desc(sb)}) and {a} ({desc(sa)}) each run on 4 to 5 augmented views (full frame, two centre crops, mirror, and a crop around the salient box when the plant is small); the calibrated probabilities are averaged. {b} also supplies an embedding that is compared with per-species centroids (`Resources/embeddings.json`); a call below its species' similarity floor is downgraded.",
             f"- Confirm rule: Tier 1 top class, calibrated probability at least {card['tier1']['confirmThreshold']:.2f} (per-species floors from validation), margin 0.30 over the runner-up, low entropy, inside the similarity floor.", "",
             "## Head to head on the same images", "",
             "| Model | Top-1 | Top-3 | Tier 1 top-1 | Tier 2 top-1 | Natives top-1 | Other plant | Confirm precision | Confirm coverage | Flagged: natives | Flagged: wild other plants | Flagged: not a plant |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|"]
        for k in (a, b, "ensemble"):
            r = out[k]
            L.append(f"| {k} | {pct(r['top1_all'])} | {pct(r.get('top3_all'))} | {pct(r['tier1']['top1'])} | {pct(r['tier2']['top1'])} | {pct(r['native']['top1'])} | {pct(r['other_plant']['top1'])} | {pct(r['confirm_precision'])} | {pct(r['confirm_coverage_tier1'])} | {pct(r['flagged_natives'])} | {pct(r['flagged_other_plant_wild'])} | {pct(r['flagged_not_plant'])} |")
        L += ["", "'Flagged' = the app would show the photo as a confirmed or possible invasive (a false alarm when the photo is a native, another plant, or not a plant). 'Coverage' = the share of true Tier 1 photos that come back confirmed; the rest go to expert review.", "",
              f"## Training data", f"- {b}: {sb['split_sizes']['train']:,} train / {sb['split_sizes']['val']:,} val / {sb['split_sizes']['test']:,} test images, {len(sb['labels'])} classes ({sum(1 for l in sb['labels'] if sb['tiers'][l]=='tier1')} Tier 1, {sum(1 for l in sb['labels'] if sb['tiers'][l]=='tier2')} Tier 2, {sum(1 for l in sb['labels'] if sb['tiers'][l]=='native')} natives, other_plant, not_plant); trail-camera augmentation {'on' if sb.get('field_aug') else 'off'}.",
              f"- {a}: {sa['split_sizes']['train']:,} / {sa['split_sizes']['val']:,} / {sa['split_sizes']['test']:,} images, {len(sa['labels'])} classes; trail-camera augmentation {'on' if sa.get('field_aug') else 'off'}.", "",
              "## Calibration", f"- Temperature scaling per model on validation; test ECE {evb['ece_test']:.4f} ({b}).", "",
              "## Hardest confusions (" + b + ", test, true -> predicted, count)"] + [f"- {h}" for h in evb["hardestConfusions"][:12]] + ["",
              "## Field conditions (held-out test photos degraded like trail shots)",
              "Measured by `model/field_eval.py`: dim understory, dusk with sensor noise, flashlight, backlight, harsh sun, dappled canopy light, hand-shake and focus blur, a small far-away subject, a tight zoom, colour casts, JPEG, rotation, low resolution. Top-1 per condition:", "",
              "| Condition | " + " | ".join(field.keys()) + " |", "|---|" + "---|" * len(field)]
        if field:
            conds = list(next(iter(field.values()))["conditions"].keys())
            for c in conds:
                L.append(f"| {c} | " + " | ".join(pct(f["conditions"][c]["top1"]) for f in field.values()) + " |")
            L.append("| **mean over degraded** | " + " | ".join(pct(f["mean_over_degraded"]["top1"]) for f in field.values()) + " |")
        if before:
            L += ["", "## The preserve's common natives",
                  f"- Before (shipped v3+v2 on {before['photos']} held-out photos of the 74 common natives nearby): native {pct(before['decisions'].get('native',0)/before['photos'])}, not sure {pct(before['decisions'].get('rescan',0)/before['photos'])}, flagged as invasive {pct(before['flaggedAsInvasive'])} (`model/eval/local_natives_before_v3+v2.json`).",
                  f"- Now: these species are named classes; their held-out accuracy is in the per-class table of `model/eval/{b}_eval.json`, and the 'Flagged: natives' column above includes them."]
        L += ["",
              "## Honest limits",
              "- These are iNaturalist photos, many of them clean close-ups by people who already knew the plant. Field accuracy on a phone in the preserve will be lower; Field Test mode measures it and no field number is claimed until then.",
              "- Tier 2 results are never shown as confirmed. Unknown plants are refused rather than guessed.",
              "- AI suggestion, not a guarantee. Staff make the final call."]
        (ROOT / "docs" / "MODEL_CARD.md").write_text("\n".join(L) + "\n")
        print("wrote model card for the ensemble")

if __name__ == "__main__":
    main()
