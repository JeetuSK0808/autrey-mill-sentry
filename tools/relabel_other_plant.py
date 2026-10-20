#!/usr/bin/env python3
"""Move other_plant photos whose observation taxon is now a named class into that class folder, and fix attribution.csv.
The taxon of each other_plant observation comes from the cached /observations pages (data/cache). Run after `fetch_inat.py survey`
and before `download`. Idempotent."""
import csv, json, pathlib, shutil, collections
ROOT = pathlib.Path(__file__).resolve().parent.parent
classes = json.loads((ROOT / "model/classes.json").read_text())["classes"]
by_taxon = {c["taxon_id"]: c["label"] for c in classes if c["taxon_id"] and c["label"] != "other_plant"}
obs2tax = {}
for f in (ROOT / "data/cache").glob("*without_taxon_id*"):
    try: j = json.loads(f.read_text())
    except Exception: continue
    for o in j.get("results", []):
        obs2tax[o["id"]] = (o.get("taxon") or {}).get("id")
moved = collections.Counter(); moved_photo = {}
src = ROOT / "data/images/other_plant"
for p in sorted(src.glob("*.jpg")):
    stem = p.stem.replace("cult_", ""); oid = int(stem.split("_")[0]); pid = stem.split("_", 1)[1]
    label = by_taxon.get(obs2tax.get(oid))
    if not label: continue
    dest = ROOT / "data/images" / label; dest.mkdir(parents=True, exist_ok=True)
    shutil.move(str(p), str(dest / f"{oid}_{pid}.jpg")); moved[label] += 1; moved_photo[pid] = label
attr = ROOT / "data/attribution.csv"
rows = list(csv.DictReader(open(attr)))
for r in rows:
    if r["class"] == "other_plant" and r["photo_id"] in moved_photo: r["class"] = moved_photo[r["photo_id"]]
with open(attr, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=rows[0].keys()); w.writeheader(); w.writerows(rows)
print("moved", sum(moved.values()), "photos into", len(moved), "classes;", moved.most_common(8))
