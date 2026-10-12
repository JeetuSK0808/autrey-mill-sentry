#!/usr/bin/env python3
"""Export the trained model to Core ML (FP16 .mlpackage, classifier with labels, temperature folded in) and verify against PyTorch.

Usage: model/.venv/bin/python -I model/export_coreml.py --version v1
"""
import argparse, json, pathlib
import numpy as np, torch, torch.nn as nn, timm, coremltools as ct
from PIL import Image
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa: E402

class Wrapped(nn.Module):
    """Takes RGB in [0,1], applies exact per-channel ImageNet normalisation, the backbone, temperature and softmax."""
    def __init__(self, m, T):
        super().__init__(); self.m = m; self.T = T
        self.register_buffer("mean", torch.tensor(MEAN).view(1, 3, 1, 1)); self.register_buffer("std", torch.tensor(STD).view(1, 3, 1, 1))
    def forward(self, x): return torch.softmax(self.m((x - self.mean) / self.std) / self.T, dim=1)

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--version", default="v1"); args = ap.parse_args()
    ck = torch.load(MODEL / "checkpoints" / f"{args.version}_best.pt", map_location="cpu", weights_only=False)
    ev = json.load(open(EVAL / f"{args.version}_eval.json"))
    labels, size, T = ck["labels"], ck["size"], ev["temperature"]
    model = timm.create_model(ck["arch"], pretrained=False, num_classes=len(labels)); model.load_state_dict(ck["state_dict"]); model.eval()
    wrapped = Wrapped(model, T).eval()
    example = torch.rand(1, 3, size, size)
    traced = torch.jit.trace(wrapped, example)
    # ImageType delivers pixels 0..255; scale to [0,1] here, exact per-channel normalisation lives inside the graph.
    mlmodel = ct.convert(traced, inputs=[ct.ImageType(name="image", shape=(1, 3, size, size), scale=1 / 255.0, color_layout=ct.colorlayout.RGB)],
                         classifier_config=ct.ClassifierConfig(labels), convert_to="mlprogram", compute_precision=ct.precision.FLOAT16,
                         minimum_deployment_target=ct.target.iOS17)
    mlmodel.author = "Jeetu SK"
    mlmodel.short_description = "Autrey Mill Sentry invasive plant classifier (calibrated softmax)."
    mlmodel.version = args.version
    mlmodel.license = "Student project. Trained on CC-licensed iNaturalist photos; see docs/LICENSES.md."
    out = RES / "InvasiveClassifier.mlpackage"
    if out.exists():
        import shutil; shutil.rmtree(out)
    mlmodel.save(str(out))
    size_mb = sum(p.stat().st_size for p in out.rglob("*") if p.is_file()) / 1e6
    print(f"saved {out} ({size_mb:.1f} MB)", flush=True)

    # verify on a batch of test images
    tst = np.load(EVAL / f"{args.version}_logits_test.npz")
    paths = tst["paths"][:: max(1, len(tst["paths"]) // 40)][:40]
    from torchvision.transforms import v2 as TV
    agree, maxdiff = 0, 0.0
    for p in paths:
        img = Image.open(p).convert("RGB")
        # identical geometry for both: shorter side -> 256 (antialias), centre crop 224
        im2 = TV.CenterCrop(size)(TV.Resize(int(size * 1.14), antialias=True)(img))
        x = TV.ToDtype(torch.float32, scale=True)(TV.ToImage()(im2))[None]
        with torch.no_grad(): pt = wrapped(x).numpy()[0]
        pred = mlmodel.predict({"image": im2})
        probs = pred[[k for k in pred if k != "classLabel"][0]]
        cm = np.array([probs[l] for l in labels])
        agree += int(cm.argmax() == pt.argmax()); maxdiff = max(maxdiff, float(np.abs(cm - pt).max()))
    rep = {"version": args.version, "images_checked": len(paths), "top1_agreement": agree / len(paths), "max_abs_prob_diff": maxdiff, "size_mb": size_mb, "temperature": T, "note": "Same 224 px centre crop fed to both; differences come from FP16 and Core ML resampling only."}
    json.dump(rep, open(EVAL / f"{args.version}_coreml_check.json", "w"), indent=1)
    print(rep, flush=True)

if __name__ == "__main__":
    main()
