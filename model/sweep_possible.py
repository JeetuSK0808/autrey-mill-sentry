#!/usr/bin/env python3
"""Pick the 'possible invasive' bar and gate strictness for the ensemble: cultivated holdout flags vs true invasives kept.
Usage: model/.venv/bin/python -I model/sweep_possible.py v2 v3"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa: E402
import numpy as np
from eval_holdout import run, softmax

def main():
    a, b = sys.argv[1], sys.argv[2]
    import torch; device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
    tiers = json.load(open(MODEL / "runs" / f"{b}_split.json"))["tiers"]
    te = np.load(EVAL / f"{b}_logits_test.npz"); test_paths = [str(p) for p in te["paths"]]
    labels_b = json.load(open(MODEL / "runs" / f"{b}_split.json"))["labels"]
    y_test = np.array([labels_b[int(y)] for y in te["y"]])
    hold_paths = sorted(str(p) for p in (DATA / "holdout_cultivated").glob("*.jpg"))
    sets = {}
    for v in (a, b):
        ev = json.load(open(EVAL / f"{v}_eval.json")); cen = json.load(open(EVAL / f"{v}_centroids.json"))["classes"]
        for name, paths in (("test", test_paths), ("hold", hold_paths)):
            labels, L, E = run(v, paths, device)
            sets[(v, name)] = dict(labels=labels, P=softmax(L / ev["temperature"]), E=E,
                                    C=np.array([cen[l]["centroid"] for l in labels], dtype=np.float32), floors=np.array([cen[l]["minCosine"] for l in labels]))
    thr = json.load(open(EVAL / f"{b}_thresholds.json")); per = thr["perClassConfirmMin"]; g = thr["confirmMinProbability"]; margin = thr["confirmMinMargin"]
    def ens(name):
        kb, ka = sets[(b, name)], sets[(a, name)]; idx = [ka["labels"].index(l) for l in kb["labels"]]
        return kb["labels"], (kb["P"] + ka["P"][:, idx]) / 2, kb["E"], kb["C"], kb["floors"]
    rows = []
    for pm in (0.45, 0.50, 0.55, 0.60, 0.65):
        for strict in (False, True):
            out = {"possibleMin": pm, "gateStrictForPossible": strict}
            for name in ("hold", "test"):
                labels, P, E, C, floors = ens(name)
                top = P.argmax(1); conf = P.max(1); srt = np.sort(P, 1); mg = srt[:, -1] - srt[:, -2]
                sim = (E @ C.T)[np.arange(len(top)), top]; floor = floors[top]
                pred = np.array([labels[t] for t in top])
                t1 = np.array([tiers[l] == "tier1" for l in pred]); inv = np.array([tiers[l] in ("tier1", "tier2") for l in pred])
                thr_vec = np.array([per.get(l, g) for l in pred])
                confirmed = t1 & (conf >= thr_vec) & (mg >= margin) & (sim >= floor)
                gate_ok = (sim >= floor) if strict else ~(sim < floor - 0.05)
                possible = inv & (conf >= pm) & gate_ok & ~confirmed
                flagged = confirmed | possible
                if name == "hold":
                    out["holdout_flagged"] = float(flagged.mean()); out["holdout_confirmed"] = float(confirmed.mean())
                else:
                    true_inv = np.array([tiers.get(n, "other") in ("tier1", "tier2") for n in y_test]); nat = np.array([tiers.get(n, "other") == "native" for n in y_test])
                    wild = (y_test == "other_plant")
                    out["test_true_invasives_flagged"] = float(flagged[true_inv].mean()); out["test_natives_flagged"] = float(flagged[nat].mean()); out["test_wild_other_flagged"] = float(flagged[wild].mean())
            rows.append(out); print(json.dumps(out), flush=True)
    json.dump(rows, open(EVAL / "sweep_possible_ensemble.json", "w"), indent=1)

if __name__ == "__main__":
    main()
