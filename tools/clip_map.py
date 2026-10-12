#!/usr/bin/env python3
"""Clip the raw OSM GeoJSON to the preserve: keep the park boundary, trails/water/POIs within a margin of it.
Hand edits (names, notes) are applied here so the pipeline is reproducible: python3 -I tools/clip_map.py"""
import json, math, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / "AutreyMillSentry" / "Resources"
MARGIN_M = 120.0
ATTR = "Map data (c) OpenStreetMap contributors, ODbL 1.0. https://www.openstreetmap.org/copyright"

def load(n): return json.loads((RES / n).read_text())["features"]
boundary = load("boundary.geojson")
park = next(f for f in boundary if f["properties"].get("osm_id") == 589352774)  # leisure=park "Autrey Mill Park"
ring = park["geometry"]["coordinates"][0]
lat0 = sum(c[1] for c in ring) / len(ring)
kx = math.cos(math.radians(lat0)) * 111320.0; ky = 110540.0
def proj(c): return ((c[0] - ring[0][0]) * kx, (c[1] - ring[0][1]) * ky)
P = [proj(c) for c in ring]
def inside(pt):
    x, y = pt; n = len(P); ins = False; j = n - 1
    for i in range(n):
        xi, yi = P[i]; xj, yj = P[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
            ins = not ins
        j = i
    return ins
def seg_dist(p, a, b):
    px, py = p; ax, ay = a; bx, by = b
    dx, dy = bx - ax, by - ay
    if dx == dy == 0: return math.hypot(px - ax, py - ay)
    t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))
def dist_to_ring(pt):
    return min(seg_dist(pt, P[i], P[(i + 1) % len(P)]) for i in range(len(P)))
def near(c):
    pt = proj(c)
    return inside(pt) or dist_to_ring(pt) <= MARGIN_M
def coords_of(f):
    g = f["geometry"]
    if g["type"] == "Point": return [g["coordinates"]]
    if g["type"] == "LineString": return g["coordinates"]
    return g["coordinates"][0]
def keep(f, frac=0.5):
    cs = coords_of(f)
    return sum(near(c) for c in cs) >= max(1, frac * len(cs))

trails = [f for f in load("trails.geojson") if f["properties"]["kind"] == "trail" and keep(f, 0.3)]
water = [f for f in load("waterways.geojson") if keep(f, 0.2)]
poi = [f for f in load("poi.geojson") if keep(f, 0.99)]
# drop anonymous houses outside the park, keep named buildings and park furniture
poi = [f for f in poi if not (f["properties"].get("kind") == "building" and not f["properties"].get("name") and not inside(proj(coords_of(f)[0])))]
park["properties"]["role"] = "preserve_boundary"
park["properties"]["display_name"] = "Autrey Mill Nature Preserve"
# Trails in OSM are split into many ways; give unnamed ways a stable display label.
for f in trails:
    p = f["properties"]
    if not p.get("name"):
        p["display_name"] = "Unnamed trail"
    else:
        p["display_name"] = p["name"]
for f in water:
    p = f["properties"]
    p["display_name"] = p.get("name") or ("Pond" if f["geometry"]["type"] == "Polygon" else "Stream")
def write(name, feats, note):
    fc = {"type": "FeatureCollection", "attribution": ATTR, "note": note, "features": feats}
    (RES / name).write_text(json.dumps(fc, separators=(",", ":")))
    print(name, len(feats))
write("trails.geojson", trails, "OSM footways within 120 m of the Autrey Mill Park polygon (way 589352774). Retrieved 2026-10-12.")
write("boundary.geojson", [park], "OSM way 589352774 (leisure=park, Autrey Mill Park). Retrieved 2026-10-12.")
write("waterways.geojson", water, "OSM waterways and water bodies near the preserve, including Sal's Creek (way 33156205). Retrieved 2026-10-12.")
write("poi.geojson", poi, "OSM points of interest and named buildings inside or near the preserve. Retrieved 2026-10-12.")
