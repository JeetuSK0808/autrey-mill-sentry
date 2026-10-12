#!/usr/bin/env python3
"""Append a per-observer credit list (by license) to docs/LICENSES.md from data/attribution.csv."""
import csv, pathlib, collections
ROOT = pathlib.Path(__file__).resolve().parent.parent
by = collections.defaultdict(lambda: collections.Counter())
n = 0
with open(ROOT / "data" / "attribution.csv") as f:
    for r in csv.DictReader(f):
        by[r["license"]][r["observer"]] += 1; n += 1
lines = [f"\n### Observer credits ({n} photos, generated {__import__('time').strftime('%Y-%m-%d')})\n"]
for lic in sorted(by):
    obs = by[lic]
    lines.append(f"\n**{lic.upper()}** ({sum(obs.values())} photos from {len(obs)} observers): " + ", ".join(f"{o} ({c})" for o, c in sorted(obs.items())) + "\n")
p = ROOT / "docs" / "LICENSES.md"
s = p.read_text().split("### Observer credits")[0].rstrip() + "\n" + "".join(lines)
p.write_text(s)
print("updated", p, n, "photos")
