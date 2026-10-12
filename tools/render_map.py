#!/usr/bin/env python3
"""Render the bundled GeoJSON to a PNG so it can be compared with the official trail map by eye."""
import json, math, pathlib, sys
from PIL import Image, ImageDraw, ImageFont
ROOT = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / "AutreyMillSentry" / "Resources"
OUT = ROOT / "data" / "raw" / (sys.argv[1] if len(sys.argv) > 1 else "osm_render.png")
W, H = 1600, 2000
def load(n): return json.loads((RES / n).read_text())["features"]
trails, boundary, water, poi = load("trails.geojson"), load("boundary.geojson"), load("waterways.geojson"), load("poi.geojson")
# frame on the park polygon
park = [f for f in boundary if f["properties"].get("name") in ("Autrey Mill Park", "Autrey Mill Nature Preserve")]
pts = [c for f in park for c in f["geometry"]["coordinates"][0]]
lons = [p[0] for p in pts]; lats = [p[1] for p in pts]
mlon, mlat = (min(lons)+max(lons))/2, (min(lats)+max(lats))/2
dlon, dlat = (max(lons)-min(lons))*1.25, (max(lats)-min(lats))*1.25
kx = math.cos(math.radians(mlat))
scale = min(W/(dlon*kx), H/dlat)
def xy(c):
    return ((c[0]-mlon)*kx*scale + W/2, H/2 - (c[1]-mlat)*scale)
img = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(img)
try: font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 22)
except Exception: font = ImageFont.load_default()
for f in boundary:
    g = f["geometry"]
    if g["type"] == "Polygon":
        col = "red" if f["properties"].get("leisure") == "park" else "#88cc88"
        d.polygon([xy(c) for c in g["coordinates"][0]], outline=col)
        c0 = xy(g["coordinates"][0][0]); d.text(c0, str(f["properties"].get("name", f["properties"]["osm_id"])), fill=col, font=font)
for f in water:
    g = f["geometry"]
    if g["type"] == "LineString":
        d.line([xy(c) for c in g["coordinates"]], fill="blue", width=4)
        c0 = xy(g["coordinates"][len(g["coordinates"])//2]); d.text(c0, f["properties"].get("name", "stream"), fill="blue", font=font)
    else:
        d.polygon([xy(c) for c in g["coordinates"][0]], fill="#cce5ff", outline="blue")
for f in trails:
    g = f["geometry"]; p = f["properties"]
    col = "black" if p["kind"] == "trail" else "#bbbbbb"
    d.line([xy(c) for c in g["coordinates"]], fill=col, width=6 if p["kind"] == "trail" else 3)
    if p.get("name") and p["kind"] == "trail":
        c0 = xy(g["coordinates"][len(g["coordinates"])//2]); d.text(c0, p["name"], fill="black", font=font)
for f in poi:
    g = f["geometry"]; p = f["properties"]
    if g["type"] == "Point":
        x, y = xy(g["coordinates"]); d.ellipse([x-6, y-6, x+6, y+6], fill="orange")
        d.text((x+8, y-8), f"{p.get('kind')} {p.get('name','')}", fill="darkorange", font=font)
    elif g["type"] == "Polygon" and p.get("name"):
        d.polygon([xy(c) for c in g["coordinates"][0]], outline="purple")
        d.text(xy(g["coordinates"][0][0]), p["name"], fill="purple", font=font)
img.save(OUT); print("wrote", OUT)
