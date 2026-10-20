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

def make_transforms(size=224, train=True, field=False):
    """`field=True` adds the trail-camera conditions measured weak by model/field_eval.py on v3: deep shade and dusk noise,
    flashlight vignette, backlight, dappled canopy light, hand-shake and focus blur, small far-away subjects, low resolution."""
    from torchvision.transforms import v2 as T
    import torch
    if train and field:
        return T.Compose([
            FarSubject(p=0.22),
            T.RandomResizedCrop(size, scale=(0.25, 1.0), ratio=(0.7, 1.4), antialias=True),
            T.RandomHorizontalFlip(),
            T.RandomApply([T.RandomRotation(25)], p=0.5),
            T.RandomApply([T.RandomRotation((90, 90))], p=0.15),
            T.ColorJitter(brightness=0.35, contrast=0.4, saturation=0.35, hue=0.04),
            T.RandomApply([T.GaussianBlur(7, sigma=(0.3, 2.8))], p=0.25),
            T.RandomGrayscale(p=0.02),
            T.RandomApply([T.JPEG(quality=(25, 80))], p=0.25),
            T.ToImage(), T.ToDtype(torch.float32, scale=True),
            FieldLight(),
            T.Normalize(MEAN, STD),
            T.RandomErasing(p=0.15, scale=(0.02, 0.12)),
        ])
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

class FarSubject:
    """PIL -> PIL. With probability p, shrink the photo to 30..60 % and paste it on a blurred, darker, zoomed copy of itself,
    so the subject is small inside realistic foliage (the phone held far from the plant)."""
    def __init__(self, p=0.2): self.p = p
    def __call__(self, img):
        if random.random() >= self.p: return img
        from PIL import ImageFilter, ImageEnhance
        w, h = img.size
        bg = img.resize((w * 2, h * 2)).crop((w // 2, h // 2, w // 2 + w, h // 2 + h)).filter(ImageFilter.GaussianBlur(random.uniform(3, 8)))
        bg = ImageEnhance.Brightness(bg).enhance(random.uniform(0.5, 0.9))
        s = random.uniform(0.3, 0.6); sm = img.resize((max(8, int(w * s)), max(8, int(h * s))))
        bg.paste(sm, (int((w - sm.size[0]) * random.uniform(0.15, 0.85)), int((h - sm.size[1]) * random.uniform(0.15, 0.85))))
        return bg

class FieldLight:
    """Float tensor [3,H,W] in 0..1 -> same. Lighting on the trail: exposure gain (deep shade to harsh sun), gamma,
    dappled canopy light, backlight haze, flashlight vignette with a warm cast, white-balance drift, sensor noise in the dark,
    and hand-shake motion blur. Each effect is applied independently with its own probability."""
    def __call__(self, x):
        import torch, torch.nn.functional as F, math
        C, H, W = x.shape
        r = random.random()
        if r < 0.30:                                       # darker: shade, dusk (log-uniform gain 0.12..0.8)
            x = x * math.exp(random.uniform(math.log(0.15), math.log(0.85)))
        elif r < 0.42:                                     # brighter: harsh sun with clipping
            x = x * random.uniform(1.3, 2.2) - random.uniform(0, 0.15)
        if random.random() < 0.3:
            x = x.clamp(0, 1) ** random.uniform(0.6, 1.6)   # gamma
        if random.random() < 0.3:                          # dappled light
            g = torch.rand(1, 1, random.randint(3, 7), random.randint(3, 7))
            mask = F.interpolate(g, size=(H, W), mode="bilinear", align_corners=False)[0]
            x = x * (0.3 + 1.15 * mask ** 1.5)
        if random.random() < 0.12:                         # backlight haze
            grad = torch.linspace(random.uniform(0.3, 0.6), 0, H).view(1, H, 1)
            x = x * random.uniform(0.7, 0.9) + random.uniform(0.05, 0.2) + grad
        if random.random() < 0.12:                         # flashlight: bright warm centre, dark edges
            yy, xx = torch.meshgrid(torch.linspace(-0.5, 0.5, H), torch.linspace(-0.5, 0.5, W), indexing="ij")
            rr = torch.sqrt(yy ** 2 + xx ** 2); spot = (1.35 - random.uniform(2.0, 3.0) * rr).clamp(0.1, 1.35)
            x = x * spot * torch.tensor([1.08, 1.0, 0.82]).view(3, 1, 1)
        if random.random() < 0.3:                          # white balance drift
            x = x * torch.tensor([random.uniform(0.82, 1.18), random.uniform(0.95, 1.05), random.uniform(0.78, 1.2)]).view(3, 1, 1)
        x = x.clamp(0, 1)
        if random.random() < 0.3:                          # sensor noise, stronger when dark
            sigma = random.uniform(0.01, 0.03) + (0.03 if x.mean() < 0.25 else 0)
            x = (x + torch.randn_like(x) * sigma).clamp(0, 1)
        if random.random() < 0.12:                         # motion blur line kernel
            k = random.choice([7, 9, 11, 13]); c = k // 2; ang = random.uniform(0, math.pi); ker = torch.zeros(k, k)
            for t in torch.linspace(-c, c, 4 * k):
                ker[int(round(c + float(t) * math.sin(ang))), int(round(c + float(t) * math.cos(ang)))] = 1
            ker = (ker / ker.sum())[None, None].repeat(3, 1, 1, 1)
            x = F.conv2d(F.pad(x[None], (c, c, c, c), mode="reflect"), ker, groups=3)[0]
        if random.random() < 0.15:                         # low resolution (digital zoom, far subject)
            s = random.randint(72, 160)
            x = F.interpolate(F.interpolate(x[None], size=(s, s), mode="bilinear", antialias=True), size=(H, W), mode="bilinear")[0]
        return x

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
