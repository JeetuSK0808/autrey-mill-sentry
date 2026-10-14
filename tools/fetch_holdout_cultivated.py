#!/usr/bin/env python3
"""Fresh cultivated/house/garden plant photos that no model has seen (newest first, photo ids not in attribution.csv).
Used only to measure how often the app flags a houseplant as an invasive. Writes data/holdout_cultivated/*.jpg + holdout_attribution.csv"""
import csv, os, sys, pathlib, time, urllib.request, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fetch_inat import api_get, fetch_photo, ALLOWED, UA, GEORGIA, US, ROOT, MODEL
DATA = ROOT / "data"
OUT = DATA / "holdout_cultivated"; OUT.mkdir(parents=True, exist_ok=True)
seen = set()
with open(DATA / "attribution.csv") as f:
    for r in csv.DictReader(f): seen.add(r["photo_id"])
classes = json.loads((MODEL / "classes.json").read_text())["classes"]
all_taxa = ",".join(str(c["taxon_id"]) for c in classes if c["taxon_id"] and c["label"] != "other_plant")
target = int(sys.argv[1]) if len(sys.argv) > 1 else 300
rows = []; count = len(list(OUT.glob("*.jpg")))
page = 1
while count < target and page <= 30:
    j = api_get("/observations", {"taxon_id": 47126, "without_taxon_id": all_taxa, "captive": "true", "photos": "true", "photo_license": "cc0,cc-by,cc-by-nc",
                                  "place_id": US, "rank": "species", "per_page": 200, "order_by": "created_at", "order": "desc", "page": page})
    page += 1
    for o in j.get("results", []):
        if count >= target: break
        for ph in o.get("photos", [])[:1]:
            lic = (ph.get("license_code") or "").lower(); pid = str(ph["id"])
            if lic not in ALLOWED or pid in seen: continue
            dest = OUT / f"{o['id']}_{pid}.jpg"
            if fetch_photo(ph["url"].replace("square", "medium"), dest):
                rows.append([o["id"], pid, (o.get("user") or {}).get("login", ""), lic, ph["url"], f"https://www.inaturalist.org/observations/{o['id']}", (o.get("taxon") or {}).get("name", "")])
                seen.add(pid); count += 1
with open(DATA / "holdout_attribution.csv", "a", newline="") as f:
    w = csv.writer(f)
    if f.tell() == 0: w.writerow(["observation_id", "photo_id", "observer", "license", "photo_url", "observation_url", "taxon"])
    w.writerows(rows)
print("holdout cultivated images:", len(list(OUT.glob("*.jpg"))))
