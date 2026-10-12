#!/usr/bin/env python3
"""Train the invasive plant classifier on MPS. Observer-level split, class-balanced sampling, strong augmentation.

Usage: model/.venv/bin/python -I model/train.py --arch mobilenetv3_large_100 --epochs 14 --size 224 --version v1
Outputs: model/checkpoints/<version>_best.pt, model/runs/<version>_log.json, model/eval/<version>_logits_{val,test}.npz
"""
import argparse, json, math, os, time, pathlib, random
import numpy as np
import torch, torch.nn as nn, torch.nn.functional as F
from torch.utils.data import DataLoader, WeightedRandomSampler
import timm
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa: E402

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--arch", default="mobilenetv3_large_100")
    ap.add_argument("--epochs", type=int, default=14)
    ap.add_argument("--size", type=int, default=224)
    ap.add_argument("--batch", type=int, default=64)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--version", default="v1")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--max-per-class", type=int, default=0, help="debug: cap training images per class")
    args = ap.parse_args()

    torch.manual_seed(0); random.seed(0); np.random.seed(0)
    device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
    labels, tiers, cls = load_classes()
    items, counts = build_index(labels)
    present = sorted({it["label"] for it in items}, key=labels.index)
    label_to_idx = {l: i for i, l in enumerate(present)}
    for it in items: it["label_idx"] = label_to_idx[it["label"]]
    train = [it for it in items if it["split"] == "train"]
    val = [it for it in items if it["split"] == "val"]
    test = [it for it in items if it["split"] == "test"]
    if args.max_per_class:
        by = {}
        for it in train: by.setdefault(it["label"], []).append(it)
        train = [it for l in by for it in by[l][:args.max_per_class]]
    print(f"classes={len(present)} train={len(train)} val={len(val)} test={len(test)} device={device}", flush=True)
    (MODEL / "runs").mkdir(exist_ok=True); (MODEL / "checkpoints").mkdir(exist_ok=True); EVAL.mkdir(exist_ok=True)
    json.dump({"labels": present, "tiers": {l: tiers[l] for l in present}, "counts": {l: counts[l] for l in present},
               "split_sizes": {"train": len(train), "val": len(val), "test": len(test)},
               "val_observers": len({it["observer"] for it in val}), "test_observers": len({it["observer"] for it in test}),
               "train_observers": len({it["observer"] for it in train})},
              open(MODEL / "runs" / f"{args.version}_split.json", "w"), indent=1)

    # class-balanced sampling: weight ~ 1/sqrt(freq)
    freq = np.bincount([it["label_idx"] for it in train], minlength=len(present)).astype(float)
    w = 1.0 / np.sqrt(np.maximum(freq, 1))
    sample_w = torch.tensor([w[it["label_idx"]] for it in train], dtype=torch.double)
    sampler = WeightedRandomSampler(sample_w, num_samples=len(train), replacement=True)
    tr_ds = ImageListDataset(train, make_transforms(args.size, True))
    va_ds = ImageListDataset(val, make_transforms(args.size, False))
    te_ds = ImageListDataset(test, make_transforms(args.size, False))
    tr = DataLoader(tr_ds, batch_size=args.batch, sampler=sampler, num_workers=args.workers, persistent_workers=True, drop_last=True)
    va = DataLoader(va_ds, batch_size=128, num_workers=args.workers)
    te = DataLoader(te_ds, batch_size=128, num_workers=args.workers)

    model = timm.create_model(args.arch, pretrained=True, num_classes=len(present), drop_rate=0.2).to(device)
    opt = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=0.02)
    steps = args.epochs * len(tr)
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=args.lr, total_steps=steps, pct_start=0.1)
    crit = nn.CrossEntropyLoss(label_smoothing=0.1)

    def evaluate(loader):
        model.eval(); logits, ys = [], []
        with torch.no_grad():
            for x, y in loader:
                logits.append(model(x.to(device)).float().cpu()); ys.append(y)
        L = torch.cat(logits); Y = torch.cat(ys)
        top1 = (L.argmax(1) == Y).float().mean().item()
        top3 = (L.topk(3, 1).indices == Y[:, None]).any(1).float().mean().item()
        return L.numpy(), Y.numpy(), top1, top3

    log, best = [], -1
    t0 = time.time()
    for ep in range(args.epochs):
        model.train(); tot, n = 0.0, 0
        for i, (x, y) in enumerate(tr):
            x, y = x.to(device), y.to(device)
            loss = crit(model(x), y)
            opt.zero_grad(set_to_none=True); loss.backward(); opt.step(); sched.step()
            tot += loss.item() * x.size(0); n += x.size(0)
            if i % 50 == 0: print(f"ep {ep} it {i}/{len(tr)} loss {loss.item():.3f} {time.time()-t0:.0f}s", flush=True)
        Lv, Yv, v1, v3 = evaluate(va)
        log.append({"epoch": ep, "train_loss": tot / n, "val_top1": v1, "val_top3": v3, "elapsed_s": time.time() - t0})
        print(f"== epoch {ep}: loss {tot/n:.3f} val top1 {v1:.4f} top3 {v3:.4f}", flush=True)
        json.dump(log, open(MODEL / "runs" / f"{args.version}_log.json", "w"), indent=1)
        if v1 > best:
            best = v1
            torch.save({"arch": args.arch, "size": args.size, "labels": present, "state_dict": model.state_dict(), "epoch": ep, "val_top1": v1},
                       MODEL / "checkpoints" / f"{args.version}_best.pt")
    ck = torch.load(MODEL / "checkpoints" / f"{args.version}_best.pt", map_location="cpu", weights_only=False)
    model.load_state_dict(ck["state_dict"]); model.to(device)
    Lv, Yv, v1, v3 = evaluate(va)
    Lt, Yt, t1, t3 = evaluate(te)
    np.savez(EVAL / f"{args.version}_logits_val.npz", logits=Lv, y=Yv)
    np.savez(EVAL / f"{args.version}_logits_test.npz", logits=Lt, y=Yt, paths=np.array([it["path"] for it in test]), observers=np.array([it["observer"] for it in test]))
    print(f"BEST epoch {ck['epoch']} val top1 {v1:.4f} top3 {v3:.4f} | test top1 {t1:.4f} top3 {t3:.4f}", flush=True)

if __name__ == "__main__":
    main()
