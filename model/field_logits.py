#!/usr/bin/env python3
"""Logits of a model on validation or test images degraded like trail shots (the conditions in field_eval.py), so that
temperature scaling and the per-species confirm floors can be tuned on field-like images, not only clean ones.

Usage: model/.venv/bin/python -I model/field_logits.py --version v4 --split val [--per-condition 700]
Writes model/eval/<version>_logits_<split>_field.npz (logits, y, condition, paths).
"""
import argparse, random, json
import numpy as np, torch, timm
from PIL import Image
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa: E402
import field_eval as FE

CONDS = [FE.dim, FE.dusk_noisy, FE.torch_lit, FE.backlit, FE.overexposed, FE.dappled, FE.motion_blur, FE.defocus, FE.far, FE.lowres]

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--version", default="v4"); ap.add_argument("--split", default="val", choices=["val", "test"])
    ap.add_argument("--per-condition", type=int, default=0, help="images per condition (default: split size / number of conditions)"); args = ap.parse_args()
    device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
    ck = torch.load(MODEL / "checkpoints" / f"{args.version}_best.pt", map_location="cpu", weights_only=False)
    labels, size = ck["labels"], ck["size"]
    model = timm.create_model(ck["arch"], pretrained=False, num_classes=len(labels)); model.load_state_dict(ck["state_dict"]); model.eval().to(device)
    split = json.load(open(MODEL / "runs" / f"{args.version}_split.json"))
    all_labels, _, _ = load_classes(); items, _ = build_index(all_labels)
    label_to_idx = {l: i for i, l in enumerate(labels)}
    pool = [it for it in items if it["split"] == args.split and it["label"] in label_to_idx]
    rng = random.Random(11); rng.shuffle(pool)
    per = args.per_condition or max(50, len(pool) // len(CONDS))
    from torchvision.transforms import v2 as TV
    prep = TV.Compose([TV.Resize(int(size * 1.14), antialias=True), TV.CenterCrop(size), TV.ToImage(), TV.ToDtype(torch.float32, scale=True), TV.Normalize(MEAN, STD)])
    L, Y, C, P = [], [], [], []
    for ci, cond in enumerate(CONDS):
        chunk = pool[ci * per:(ci + 1) * per] if (ci + 1) * per <= len(pool) else rng.sample(pool, per)
        batch, meta = [], []
        def flush():
            x = torch.stack([prep(i) for i in batch]).to(device)
            with torch.no_grad(): L.append(model(x).float().cpu().numpy())
            Y.extend(label_to_idx[m["label"]] for m in meta); C.extend([cond.__name__] * len(meta)); P.extend(m["path"] for m in meta)
        for j, it in enumerate(chunk):
            try: img = Image.open(it["path"]).convert("RGB")
            except Exception: continue
            batch.append(cond(img, np.random.default_rng(5000 + ci * 100000 + j))); meta.append(it)
            if len(batch) == 64: flush(); batch, meta = [], []
        if batch: flush()
        print(f"{cond.__name__:12s} {len(chunk)} images", flush=True)
    out = EVAL / f"{args.version}_logits_{args.split}_field.npz"
    np.savez(out, logits=np.concatenate(L), y=np.array(Y), condition=np.array(C), paths=np.array(P))
    print("wrote", out, len(Y), "rows")

if __name__ == "__main__":
    main()
