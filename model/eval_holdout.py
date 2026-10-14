#!/usr/bin/env python3
"""How often does the app flag a cultivated/house/garden plant as an invasive? Runs v2, v3 and the ensemble over
data/holdout_cultivated (fresh photos no model trained on) with the exact app rules (thresholds, gate, 'possible' bar).
Usage: model/.venv/bin/python -I model/eval_holdout.py v2 v3"""
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
    dl = DataLoader(ImageListDataset([{"path": p, "label_idx": 0} for p in paths], make_transforms(size, False)), batch_size=128, num_workers=4)
    L, E = [], []
    with torch.no_grad():
        for x, _ in dl:
            x = x.to(device); f = model.forward_head(model.forward_features(x), pre_logits=True)
            L.append(model.get_classifier()(f).float().cpu()); E.append(torch.nn.functional.normalize(f, dim=1).float().cpu())
    return labels, torch.cat(L).numpy(), torch.cat(E).numpy()

def main():
    a, b = sys.argv[1], sys.argv[2]
    device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
    paths = sorted(str(p) for p in (DATA / "holdout_cultivated").glob("*.jpg"))
    tiers = json.load(open(MODEL / "runs" / f"{b}_split.json"))["tiers"]
    res = {}; keep = {}
    for v in (a, b):
        labels, L, E = run(v, paths, device)
        ev = json.load(open(EVAL / f"{v}_eval.json")); thr_json = json.load(open(EVAL / f"{v}_thresholds.json"))
        cen = json.load(open(EVAL / f"{v}_centroids.json"))["classes"]
        C = np.array([cen[l]["centroid"] for l in labels], dtype=np.float32); floors = np.array([cen[l]["minCosine"] for l in labels])
        P = softmax(L / ev["temperature"]); keep[v] = dict(labels=labels, P=P, E=E, C=C, floors=floors, thr=thr_json)
    def apply(labels, P, E, C, floors, thr):
        top = P.argmax(1); conf = P.max(1); srt = np.sort(P, 1); mg = srt[:, -1] - srt[:, -2]
        sim = (E @ C.T)[np.arange(len(top)), top]; floor = floors[top]
        per = thr["perClassConfirmMin"]; g = thr["confirmMinProbability"]; pm = thr["possibleMinProbability"]
        t1 = np.array([tiers[labels[t]] == "tier1" for t in top]); inv = np.array([tiers[labels[t]] in ("tier1", "tier2") for t in top])
        thr_vec = np.array([per.get(labels[t], g) for t in top])
        confirmed = t1 & (conf >= thr_vec) & (mg >= thr["confirmMinMargin"]) & (sim >= floor)
        possible = inv & (conf >= pm) & ~(sim < floor - 0.05) & ~confirmed
        unknown_or_other = ~(confirmed | possible)
        return {"n": len(top), "confirmedInvasive": float(confirmed.mean()), "possibleInvasive": float(possible.mean()), "notFlagged": float(unknown_or_other.mean()),
                "confirmed_without_gate": float((t1 & (conf >= thr_vec) & (mg >= thr["confirmMinMargin"])).mean()), "possible_without_gate": float((inv & (conf >= pm)).mean())}
    for v in (a, b):
        k = keep[v]; res[v] = apply(k["labels"], k["P"], k["E"], k["C"], k["floors"], k["thr"])
    kb, ka = keep[b], keep[a]; idx = [ka["labels"].index(l) for l in kb["labels"]]
    res["ensemble"] = apply(kb["labels"], (kb["P"] + ka["P"][:, idx]) / 2, kb["E"], kb["C"], kb["floors"], kb["thr"])
    for k, r in res.items(): print(k, json.dumps(r), flush=True)
    json.dump({"holdout": "data/holdout_cultivated (fresh cultivated/house/garden plants, no model trained on them)", "results": res}, open(EVAL / "holdout_cultivated_eval.json", "w"), indent=1)

if __name__ == "__main__":
    main()
