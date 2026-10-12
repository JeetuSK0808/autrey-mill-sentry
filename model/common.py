"""Shared pieces for the Autrey Mill Sentry model pipeline: dataset index, observer-level split, transforms."""
import csv, json, hashlib, pathlib, random
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
IMG = DATA / "images"
MODEL = ROOT / "model"
EVAL = MODEL / "eval"
RES = ROOT / "AutreyMillSentry" / "Resources"
MEAN = [0.485, 0.456, 0.406]
STD = [0.229, 0.224, 0.225]

def load_classes():
    cls = json.loads((MODEL / "classes.json").read_text())["classes"]
    labels = [c["label"] for c in cls]
    tiers = {c["label"]: c["tier"] for c in cls}
    return labels, tiers, cls

def split_for(observer: str, seed: int = 20261012):
    """Deterministic observer-level split: 80/10/10 train/val/test."""
    h = int(hashlib.sha1(f"{seed}:{observer}".encode()).hexdigest(), 16) % 1000
    return "train" if h < 800 else "val" if h < 900 else "test"

def build_index(labels, min_images=20):
    """Return list of dicts: path, label, label_idx, observer, observation_id, split. Uses attribution.csv for observer."""
    attr = {}
    with open(DATA / "attribution.csv") as f:
        for row in csv.DictReader(f):
            attr[(row["class"], row["photo_id"])] = row
    items = []
    counts = defaultdict(int)
    for li, label in enumerate(labels):
        d = IMG / label
        if not d.exists():
            continue
        for p in sorted(d.glob("*.jpg")):
            obs_id, photo_id = p.stem.split("_", 1)
            row = attr.get((label, photo_id))
            observer = row["observer"] if row else f"unknown-{obs_id}"
            items.append({"path": str(p), "label": label, "label_idx": li, "observer": observer, "observation_id": obs_id,
                          "split": split_for(observer), "license": row["license"] if row else ""})
            counts[label] += 1
    keep = {l for l, n in counts.items() if n >= min_images}
    items = [it for it in items if it["label"] in keep]
    return items, counts

def make_transforms(size=224, train=True):
    from torchvision.transforms import v2 as T
    import torch
    if train:
        return T.Compose([
            T.RandomResizedCrop(size, scale=(0.35, 1.0), ratio=(0.75, 1.33), antialias=True),
            T.RandomHorizontalFlip(),
            T.RandomApply([T.RandomRotation(20)], p=0.5),
            T.ColorJitter(brightness=0.4, contrast=0.4, saturation=0.3, hue=0.03),
            T.RandomApply([T.GaussianBlur(5, sigma=(0.1, 1.5))], p=0.2),
            T.RandomGrayscale(p=0.02),
            T.ToImage(), T.ToDtype(torch.float32, scale=True),
            T.Normalize(MEAN, STD),
            T.RandomErasing(p=0.15, scale=(0.02, 0.12)),
        ])
    return T.Compose([T.Resize(int(size * 1.14), antialias=True), T.CenterCrop(size), T.ToImage(), T.ToDtype(torch.float32, scale=True), T.Normalize(MEAN, STD)])

class ImageListDataset:
    def __init__(self, items, transform):
        self.items = items; self.transform = transform
    def __len__(self): return len(self.items)
    def __getitem__(self, i):
        from PIL import Image
        it = self.items[i]
        try:
            img = Image.open(it["path"]).convert("RGB")
        except Exception:
            img = Image.new("RGB", (256, 256), (0, 0, 0))
        return self.transform(img), it["label_idx"]
