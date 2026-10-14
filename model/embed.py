#!/usr/bin/env python3
"""Compute penultimate embeddings (and calibrated probabilities) for train (subset), val and test images.
Usage: model/.venv/bin/python -I model/embed.py --version v2 --train-per-class 150
Writes model/eval/<version>_emb_{train,val,test}.npz with: emb (N,D) L2-normalised, y (N,), paths (N,)
"""
import argparse, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa: E402
import numpy as np, torch, timm
from torch.utils.data import DataLoader

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--version", default="v2"); ap.add_argument("--train-per-class", type=int, default=150); ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()
    ck = torch.load(MODEL / "checkpoints" / f"{args.version}_best.pt", map_location="cpu", weights_only=False)
    labels, size = ck["labels"], ck["size"]
    model = timm.create_model(ck["arch"], pretrained=False, num_classes=len(labels)); model.load_state_dict(ck["state_dict"]); model.eval()
    device = torch.device("mps" if torch.backends.mps.is_available() else "cpu"); model.to(device)
    items, _ = build_index(labels)
    present = {l: i for i, l in enumerate(labels)}
    items = [it for it in items if it["label"] in present]
    for it in items: it["label_idx"] = present[it["label"]]
    tf = make_transforms(size, False)
    for split in ("train", "val", "test"):
        sub = [it for it in items if it["split"] == split]
        if split == "train":
            by = {}
            for it in sub: by.setdefault(it["label"], []).append(it)
            sub = [it for l in by for it in by[l][: args.train_per_class]]
        ds = ImageListDataset(sub, tf); dl = DataLoader(ds, batch_size=128, num_workers=args.workers)
        embs, ys = [], []
        with torch.no_grad():
            for x, y in dl:
                x = x.to(device)
                f = model.forward_head(model.forward_features(x), pre_logits=True)
                embs.append(torch.nn.functional.normalize(f, dim=1).float().cpu()); ys.append(y)
        E = torch.cat(embs).numpy(); Y = torch.cat(ys).numpy()
        np.savez(EVAL / f"{args.version}_emb_{split}.npz", emb=E, y=Y, paths=np.array([it["path"] for it in sub]))
        print(f"{split}: {E.shape}", flush=True)

if __name__ == "__main__":
    main()
