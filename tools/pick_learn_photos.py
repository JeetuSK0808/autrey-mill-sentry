#!/usr/bin/env python3
"""Pick one reference photo per species for the Learn screens: the most typical licensed photo according to the
trained model (highest probability for its own class), preferring CC0 / CC-BY over CC-BY-NC and decent resolution.
Downloads the 'large' size of the chosen photo (same licence, same observation) and writes attribution.

Usage: model/.venv/bin/python -I tools/pick_learn_photos.py --version v2
Outputs: AutreyMillSentry/Resources/learn_<label>.jpg (max 1000 px, JPEG 82) and AutreyMillSentry/Resources/learn_photos.json
"""
import argparse, csv, json, os, sys, time, urllib.request, pathlib
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "model"))
import numpy as np, torch, timm
from PIL import Image
from common import ROOT, DATA, IMG, MODEL, RES, make_transforms

UA = "AutreyMillSentry/0.1 (student project, jeetusk08@gmail.com)"
LICENSE_RANK = {"cc0": 0, "cc-by": 1, "cc-by-nc": 2}

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--version", default="v2"); ap.add_argument("--per-class", type=int, default=160)
    ap.add_argument("--no-model", action="store_true", help="score by resolution, licence, aspect and Georgia origin only (labels from model/classes.json)")
    ap.add_argument("--only-missing", action="store_true", help="keep existing photos and entries; pick only for labels without one")
    args = ap.parse_args()
    if args.no_model:
        cls = json.load(open(MODEL / "classes.json"))["classes"]; labels = [c["label"] for c in cls]; model = None; tf = None; device = None
        tiers = {c["label"]: c["tier"] for c in cls}
    else:
        ck = torch.load(MODEL / "checkpoints" / f"{args.version}_best.pt", map_location="cpu", weights_only=False)
        labels = ck["labels"]; size = ck["size"]
        model = timm.create_model(ck["arch"], pretrained=False, num_classes=len(labels)); model.load_state_dict(ck["state_dict"]); model.eval()
        device = torch.device("mps" if torch.backends.mps.is_available() else "cpu"); model.to(device)
        tf = make_transforms(size, False)
        tiers = json.load(open(MODEL / "runs" / f"{args.version}_split.json"))["tiers"]
    existing = {}
    if args.only_missing and (RES / "learn_photos.json").exists():
        existing = json.load(open(RES / "learn_photos.json")).get("photos", {})
    attr = {}
    with open(DATA / "attribution.csv") as f:
        for row in csv.DictReader(f): attr[row["photo_id"]] = row
    out = dict(existing)
    for li, label in enumerate(labels):
        if label in ("other_plant", "not_plant"): continue
        if args.only_missing and label in existing and (RES / f"learn_{label}.jpg").exists(): continue
        files = sorted((IMG / label).glob("*.jpg"))[: args.per_class]
        best = None
        for p in files:
            pid = p.stem.split("_", 1)[1]; row = attr.get(pid)
            if not row: continue
            lic = row["license"]
            try:
                img = Image.open(p).convert("RGB")
            except Exception:
                continue
            w, h = img.size
            if model is None:
                prob = 1.0
                ga = 1.1 if ("GA" in (row.get("place_guess") or "") or "Georgia" in (row.get("place_guess") or "")) else 1.0
            else:
                with torch.no_grad():
                    prob = torch.softmax(model(tf(img)[None].to(device)), 1)[0, li].item()
                ga = 1.0
            score = prob * ga * min(1.0, min(w, h) / 450) * (1.0 if lic != "cc-by-nc" else 0.85) * (1.0 if 0.6 < w / h < 1.7 else 0.8)
            if best is None or score > best[0]: best = (score, prob, p, row, (w, h))
        if not best:
            print("no photo for", label); continue
        score, prob, p, row, wh = best
        # fetch the large version (1024 px) of the same photo
        large_url = row["photo_url"].replace("/medium.", "/large.")
        dest = RES / f"learn_{label}.jpg"
        data = None
        for attempt in range(3):
            try:
                req = urllib.request.Request(large_url, headers={"User-Agent": UA})
                with urllib.request.urlopen(req, timeout=60) as r: data = r.read()
                break
            except Exception as e:
                time.sleep(2)
        if data and len(data) > 5000:
            tmp = dest.with_suffix(".tmp"); tmp.write_bytes(data); img = Image.open(tmp).convert("RGB"); tmp.unlink()
        else:
            img = Image.open(p).convert("RGB")
        img.thumbnail((1000, 1000)); img.save(dest, "JPEG", quality=82, optimize=True)
        out[label] = {"file": dest.name, "observer": row["observer"], "license": row["license"], "photoURL": row["photo_url"],
                      "observationURL": row["observation_url"], "modelProbability": round(prob, 3), "tier": tiers.get(label)}
        print(f"{label:30s} p={prob:.2f} {row['license']:9s} {row['observer']}", flush=True)
        time.sleep(0.3)
    picked = ("resolution, licence, aspect and Georgia origin (no model)" if args.no_model else f"model {args.version}: most typical photo per class")
    json.dump({"source": "iNaturalist, research-grade observations; photo licences as listed", "pickedBy": picked, "photos": out},
              open(RES / "learn_photos.json", "w"), indent=1)
    total = sum(p.stat().st_size for p in RES.glob("learn_*.jpg"))
    print(f"{len(out)} photos, {total/1e6:.1f} MB")

if __name__ == "__main__":
    main()
