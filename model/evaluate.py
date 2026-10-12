#!/usr/bin/env python3
"""Calibrate (temperature scaling on val), tune the confirm thresholds on val, evaluate on test, write eval JSON + model card.

Usage: model/.venv/bin/python -I model/evaluate.py --version v1 --target-precision 0.95
Outputs: model/eval/<version>_eval.json, model/eval/thresholds.json, AutreyMillSentry/Resources/{thresholds,model_card}.json, docs/MODEL_CARD.md
"""
import argparse, json, time, pathlib
import numpy as np
from scipy.optimize import minimize_scalar
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa: E402

def softmax(z):
    z = z - z.max(1, keepdims=True); e = np.exp(z); return e / e.sum(1, keepdims=True)

def nll(T, logits, y):
    p = softmax(logits / T); return -np.log(p[np.arange(len(y)), y] + 1e-12).mean()

def ece(p, y, bins=15):
    conf = p.max(1); pred = p.argmax(1); acc = (pred == y).astype(float)
    e, edges = 0.0, np.linspace(0, 1, bins + 1)
    for lo, hi in zip(edges[:-1], edges[1:]):
        m = (conf > lo) & (conf <= hi)
        if m.any(): e += m.mean() * abs(acc[m].mean() - conf[m].mean())
    return float(e)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", default="v1")
    ap.add_argument("--target-precision", type=float, default=0.95)
    ap.add_argument("--margin", type=float, default=0.30)
    args = ap.parse_args()
    split = json.load(open(MODEL / "runs" / f"{args.version}_split.json"))
    labels, tiers = split["labels"], split["tiers"]
    V = np.load(EVAL / f"{args.version}_logits_val.npz"); Tst = np.load(EVAL / f"{args.version}_logits_test.npz")
    Lv, Yv, Lt, Yt = V["logits"], V["y"], Tst["logits"], Tst["y"]

    # 1. temperature scaling on val
    T = minimize_scalar(lambda t: nll(t, Lv, Yv), bounds=(0.5, 5.0), method="bounded").x
    Pv, Pt = softmax(Lv / T), softmax(Lt / T)
    print(f"temperature {T:.3f}  ECE val raw {ece(softmax(Lv), Yv):.4f} -> {ece(Pv, Yv):.4f}  test {ece(Pt, Yt):.4f}", flush=True)

    tier1_idx = [i for i, l in enumerate(labels) if tiers[l] == "tier1"]
    tier2_idx = [i for i, l in enumerate(labels) if tiers[l] == "tier2"]
    inv_idx = set(tier1_idx) | set(tier2_idx)

    # 2. tune a global confirm threshold on val: among test images whose top1 is Tier 1 with margin >= m,
    #    "confirmed" is correct iff true label == top1. Pick the lowest threshold with precision >= target.
    def confirm_stats(P, Y, thr, per_class=None):
        top = P.argmax(1); conf = P.max(1); srt = np.sort(P, 1); margin = srt[:, -1] - srt[:, -2]
        thr_vec = np.array([per_class.get(labels[t], thr) if per_class else thr for t in top])
        confirmed = np.isin(top, tier1_idx) & (conf >= thr_vec) & (margin >= args.margin)
        correct = confirmed & (top == Y)
        precision = correct.sum() / max(confirmed.sum(), 1)
        true_t1 = np.isin(Y, tier1_idx)
        coverage = (confirmed & true_t1 & (top == Y)).sum() / max(true_t1.sum(), 1)
        false_confirm_native = (confirmed & ~np.isin(Y, list(inv_idx))).sum() / max((~np.isin(Y, list(inv_idx))).sum(), 1)
        return float(precision), float(coverage), int(confirmed.sum()), float(false_confirm_native)
    best_thr = None
    for thr in np.arange(0.50, 0.991, 0.01):
        p, c, n, _ = confirm_stats(Pv, Yv, thr)
        if p >= args.target_precision and n >= 20:
            best_thr = float(thr); break
    if best_thr is None: best_thr = 0.95
    # per-class: for each Tier 1 class, lowest threshold reaching target precision on val (min 15 confirmed), else global
    per_class = {}
    for i in tier1_idx:
        for thr in np.arange(0.50, 0.991, 0.01):
            top = Pv.argmax(1); conf = Pv.max(1); srt = np.sort(Pv, 1); margin = srt[:, -1] - srt[:, -2]
            sel = (top == i) & (conf >= thr) & (margin >= args.margin)
            if sel.sum() >= 15 and (Yv[sel] == i).mean() >= args.target_precision:
                per_class[labels[i]] = float(max(thr, 0.5)); break
    prec_v, cov_v, n_v, _ = confirm_stats(Pv, Yv, best_thr, per_class)
    prec_t, cov_t, n_t, fcn_t = confirm_stats(Pt, Yt, best_thr, per_class)
    print(f"confirm threshold {best_thr:.2f} (+{len(per_class)} per-class) margin {args.margin}: val precision {prec_v:.3f} coverage {cov_v:.3f} | test precision {prec_t:.3f} coverage {cov_t:.3f} n={n_t}", flush=True)

    # 3. per-class metrics on test
    top = Pt.argmax(1)
    K = len(labels); cm = np.zeros((K, K), dtype=int)
    for y, t in zip(Yt, top): cm[y, t] += 1
    per = {}
    for i, l in enumerate(labels):
        tp = cm[i, i]; fp = cm[:, i].sum() - tp; fn = cm[i].sum() - tp
        per[l] = {"tier": tiers[l], "support": int(cm[i].sum()), "precision": float(tp / max(tp + fp, 1)), "recall": float(tp / max(tp + fn, 1))}
    def tier_metrics(idx):
        m = np.isin(Yt, idx)
        if not m.any(): return None
        t1 = float((top[m] == Yt[m]).mean()); t3 = float((np.argsort(-Pt[m], 1)[:, :3] == Yt[m][:, None]).any(1).mean())
        return {"classes": len(idx), "testImages": int(m.sum()), "top1": t1, "top3": t3}
    t1m, t2m = tier_metrics(tier1_idx), tier_metrics(tier2_idx)
    nat_idx = [i for i, l in enumerate(labels) if tiers[l] == "native"]
    natm = tier_metrics(nat_idx)
    # hardest confusions (off-diagonal, by count)
    off = [(cm[i, j], labels[i], labels[j]) for i in range(K) for j in range(K) if i != j and cm[i, j] > 0]
    off.sort(reverse=True)
    hardest = [f"{a} -> {b} ({n})" for n, a, b in off[:12]]
    # not_plant rejection: fraction of not_plant test images with top1 == not_plant and p >= 0.5
    npi = labels.index("not_plant") if "not_plant" in labels else None
    reject = None
    if npi is not None:
        m = Yt == npi
        reject = float(((top[m] == npi) & (Pt[m].max(1) >= 0.5)).mean()) if m.any() else None
    overall = {"top1": float((top == Yt).mean()), "top3": float((np.argsort(-Pt, 1)[:, :3] == Yt[:, None]).any(1).mean()), "testImages": int(len(Yt))}
    out = {"version": args.version, "evaluatedOn": time.strftime("%Y-%m-%d"), "temperature": float(T), "ece_val_raw": ece(softmax(Lv), Yv), "ece_val": ece(Pv, Yv), "ece_test": ece(Pt, Yt),
           "confirm": {"threshold": best_tr if (best_tr := best_thr) else best_thr, "margin": args.margin, "targetPrecision": args.target_precision, "perClass": per_class,
                       "val": {"precision": prec_v, "coverage": cov_v, "n": n_v}, "test": {"precision": prec_t, "coverage": cov_t, "n": n_t, "nativeFalseConfirmRate": fcn_t}},
           "overall": overall, "tier1": t1m, "tier2": t2m, "native": natm, "perClass": per, "hardestConfusions": hardest, "notPlantRejectRate": reject,
           "split": split["split_sizes"], "observers": {"train": split["train_observers"], "val": split["val_observers"], "test": split["test_observers"]},
           "confusion_labels": labels, "confusion": cm.tolist()}
    EVAL.mkdir(exist_ok=True)
    json.dump(out, open(EVAL / f"{args.version}_eval.json", "w"), indent=1)
    thresholds = {"confirmMinProbability": best_thr, "confirmMinMargin": args.margin, "possibleMinProbability": 0.35, "nativeMinProbability": 0.60,
                  "notPlantMinProbability": 0.50, "perClassConfirmMin": per_class, "lockOnWindow": 8, "lockOnAgreeCount": 5, "lockOnMeanProbability": 0.60,
                  "minSharpness": 40.0, "minMeanLuminance": 0.18, "maxMeanLuminance": 0.90, "maxClippedFraction": 0.25, "minSubjectFraction": 0.10,
                  "maxSubjectFraction": 0.97, "maxMotion": 0.12}
    json.dump(thresholds, open(EVAL / "thresholds.json", "w"), indent=1)
    json.dump(thresholds, open(RES / "thresholds.json", "w"), indent=1)
    card = {"status": "evaluated", "modelVersion": args.version, "evaluatedOn": out["evaluatedOn"], "testObservations": int(len(set(Tst["paths"].tolist()))) if "paths" in Tst else None,
            "tier1": {**(t1m or {}), "precisionAtConfirm": prec_t, "coverageAtConfirm": cov_t, "confirmThreshold": best_thr},
            "tier2": {**(t2m or {}), "precisionAtConfirm": None, "coverageAtConfirm": None, "confirmThreshold": None},
            "ece": out["ece_test"], "notPlantRejectRate": reject, "hardestConfusions": hardest[:5],
            "fieldAccuracy": None, "fieldPhotos": None, "dataSource": "iNaturalist research-grade photos (CC0/CC-BY/CC-BY-NC), observer-level split",
            "notes": "Held-out accuracy on iNaturalist photos. Field accuracy will be lower and is not measured yet."}
    json.dump(card, open(RES / "model_card.json", "w"), indent=1)
    write_model_card_md(out, card, labels, tiers)
    print("wrote", EVAL / f"{args.version}_eval.json")

def write_model_card_md(o, card, labels, tiers):
    pct = lambda v: "n/a" if v is None else f"{100*v:.1f}%"
    L = ["# Model card: InvasiveClassifier " + o["version"], "",
         f"Evaluated {o['evaluatedOn']}. Every number here comes from `model/eval/{o['version']}_eval.json`, produced by `model/evaluate.py` on a held-out test split.", "",
         "## Data and split",
         f"- Source: iNaturalist research-grade observations, photos licensed CC0 / CC-BY / CC-BY-NC only, Georgia first, then the south-eastern US, then the US. Attribution in `data/attribution.csv` (not committed) and `docs/LICENSES.md`.",
         f"- Split by observer (and therefore by observation): train {o['split']['train']} / val {o['split']['val']} / test {o['split']['test']} images from {o['observers']['train']} / {o['observers']['val']} / {o['observers']['test']} observers. No observer appears in two splits.",
         f"- Classes: {len(labels)} ({sum(1 for l in labels if tiers[l]=='tier1')} Tier 1, {sum(1 for l in labels if tiers[l]=='tier2')} Tier 2, {sum(1 for l in labels if tiers[l]=='native')} native look-alikes, other_plant, not_plant).", "",
         "## Calibration", f"- Temperature scaling fitted on validation: T = {o['temperature']:.3f}. ECE on validation {o['ece_val_raw']:.4f} raw -> {o['ece_val']:.4f} calibrated. ECE on test {o['ece_test']:.4f}.", "",
         "## Headline results (test split)",
         f"| Group | Classes | Test images | Top-1 | Top-3 |", "|---|---|---|---|---|",
         f"| All | {len(labels)} | {o['overall']['testImages']} | {pct(o['overall']['top1'])} | {pct(o['overall']['top3'])} |"]
    for name, key in [("Tier 1 (tuned)", "tier1"), ("Tier 2 (broad coverage)", "tier2"), ("Native look-alikes", "native")]:
        m = o.get(key)
        if m: L.append(f"| {name} | {m['classes']} | {m['testImages']} | {pct(m['top1'])} | {pct(m['top3'])} |")
    c = o["confirm"]
    L += ["", "## The confirmed-invasive call",
          f"- Target precision for `.confirmedInvasive`: {pct(c['targetPrecision'])}. Chosen on validation: global threshold {c['threshold']:.2f}, margin {c['margin']:.2f}, {len(c['perClass'])} per-class thresholds.",
          f"- Validation: precision {pct(c['val']['precision'])}, coverage {pct(c['val']['coverage'])} ({c['val']['n']} confirmed calls).",
          f"- **Test: precision {pct(c['test']['precision'])}, coverage {pct(c['test']['coverage'])}** ({c['test']['n']} confirmed calls). Coverage is the fraction of true Tier 1 photos the app confirms; the rest go to \"needs expert review\".",
          f"- Native or other plants wrongly confirmed as invasive on test: {pct(c['test']['nativeFalseConfirmRate'])}.",
          f"- not_plant photos rejected (top-1 not_plant with p >= 0.5): {pct(o['notPlantRejectRate'])}.", "",
          "## Hardest confusions (test, true -> predicted, count)"]
    L += [f"- {h}" for h in o["hardestConfusions"]]
    L += ["", "## Per-class precision / recall (test)", "| Class | Tier | Support | Precision | Recall |", "|---|---|---|---|---|"]
    for l in labels:
        p = o["perClass"][l]
        L.append(f"| {l} | {p['tier']} | {p['support']} | {pct(p['precision'])} | {pct(p['recall'])} |")
    L += ["", "## Honest limits",
          "- These are iNaturalist photos: many are clean, well-lit close-ups by people who already knew the plant. Field accuracy on a phone in the preserve will be lower. Field Test mode exists to measure that gap; no field number is claimed until it is measured.",
          "- Tier 2 accuracy is lower by design (fewer images per class). Tier 2 results are never shown as confirmed.",
          "- The model does not know rare or protected natives; they come out as other_plant.",
          "- AI suggestion, not a guarantee. Staff make the final call."]
    (ROOT / "docs" / "MODEL_CARD.md").write_text("\n".join(L) + "\n")

if __name__ == "__main__":
    main()
