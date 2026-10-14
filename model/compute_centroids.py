#!/usr/bin/env python3
"""Per-class embedding centroids and a cosine-similarity floor for the 'does this even look like that species' gate.
Usage: model/.venv/bin/python -I model/compute_centroids.py --version v2 --keep 0.95
Writes model/eval/<version>_centroids.json (also copied to Resources/embeddings.json when --bundle) and prints the
effect of the gate on confirmed-call precision/coverage and on negatives (other_plant / not_plant / natives).
"""
import argparse, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa: E402
import numpy as np

def softmax(z):
    z = z - z.max(1, keepdims=True); e = np.exp(z); return e / e.sum(1, keepdims=True)

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--version", default="v2"); ap.add_argument("--keep", type=float, default=0.95, help="fraction of true in-class validation images that must pass the gate"); ap.add_argument("--bundle", action="store_true"); args = ap.parse_args()
    split = json.load(open(MODEL / "runs" / f"{args.version}_split.json")); labels, tiers = split["labels"], split["tiers"]
    ev = json.load(open(EVAL / f"{args.version}_eval.json")); T = ev["temperature"]; thr = ev["confirm"]["threshold"]; per = ev["confirm"]["perClass"]; margin = ev["confirm"]["margin"]
    tr = np.load(EVAL / f"{args.version}_emb_train.npz"); va = np.load(EVAL / f"{args.version}_emb_val.npz"); te = np.load(EVAL / f"{args.version}_emb_test.npz")
    K = len(labels); D = tr["emb"].shape[1]
    C = np.zeros((K, D), dtype=np.float32)
    for k in range(K):
        m = tr["y"] == k
        if m.any():
            c = tr["emb"][m].mean(0); C[k] = c / max(np.linalg.norm(c), 1e-9)
    # similarity floor per class from validation: keep `keep` of true images
    floors = {}
    sims_va = (va["emb"] @ C.T)
    for k in range(K):
        m = va["y"] == k
        if m.sum() >= 10:
            floors[labels[k]] = float(np.quantile(sims_va[m, k], 1 - args.keep))
    global_floor = float(np.median(list(floors.values())))
    # evaluate the gate on test using the eval logits (same test order as logits npz? paths differ in order, so recompute via paths)
    lt = np.load(EVAL / f"{args.version}_logits_test.npz")
    path_to_idx = {str(p): i for i, p in enumerate(lt["paths"])}
    idx = np.array([path_to_idx[str(p)] for p in te["paths"]])
    P = softmax(lt["logits"][idx] / T); Y = lt["y"][idx]
    top = P.argmax(1); conf = P.max(1); srt = np.sort(P, 1); mg = srt[:, -1] - srt[:, -2]
    sims_te = (te["emb"] @ C.T); sim_top = sims_te[np.arange(len(top)), top]
    tier1 = np.array([tiers[l] == "tier1" for l in labels])
    thr_vec = np.array([per.get(labels[t], thr) for t in top])
    floor_vec = np.array([floors.get(labels[t], global_floor) for t in top])
    confirmed = tier1[top] & (conf >= thr_vec) & (mg >= margin)
    gated = confirmed & (sim_top >= floor_vec)
    def stats(mask):
        correct = mask & (top == Y); prec = correct.sum() / max(mask.sum(), 1)
        true_t1 = tier1[Y]; cov = (mask & true_t1 & (top == Y)).sum() / max(true_t1.sum(), 1)
        neg = ~np.isin(Y, [i for i, l in enumerate(labels) if tiers[l] in ("tier1", "tier2")])
        fp_neg = (mask & neg).sum() / max(neg.sum(), 1)
        return float(prec), float(cov), int(mask.sum()), float(fp_neg)
    before, after = stats(confirmed), stats(gated)
    # how often negatives get *any* species label above the possible threshold: the gate as an 'unknown' detector
    rep = {"version": args.version, "dim": int(D), "keep": args.keep, "globalFloor": global_floor,
           "test": {"withoutGate": {"precision": before[0], "coverage": before[1], "n": before[2], "negativesConfirmed": before[3]},
                    "withGate": {"precision": after[0], "coverage": after[1], "n": after[2], "negativesConfirmed": after[3]}}}
    print(json.dumps(rep["test"], indent=1), flush=True)
    out = {"version": args.version, "dim": int(D), "keepFraction": args.keep, "globalMinCosine": global_floor,
           "classes": {labels[k]: {"centroid": [round(float(v), 5) for v in C[k]], "minCosine": floors.get(labels[k], global_floor)} for k in range(K)}}
    json.dump(out, open(EVAL / f"{args.version}_centroids.json", "w"))
    json.dump(rep, open(EVAL / f"{args.version}_gate_eval.json", "w"), indent=1)
    if args.bundle:
        json.dump(out, open(RES / "embeddings.json", "w"), separators=(",", ":"))
        print("bundled Resources/embeddings.json", (RES / "embeddings.json").stat().st_size // 1024, "KB")

if __name__ == "__main__":
    main()
