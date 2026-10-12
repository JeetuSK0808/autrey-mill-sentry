#!/usr/bin/env python3
"""Fetch Autrey Mill map data from OpenStreetMap (Overpass API) and write GeoJSON.

Usage: python3 -I tools/fetch_map.py
Writes data/raw/overpass.json and AutreyMillSentry/Resources/{trails,boundary,waterways,poi}.geojson
Map data (c) OpenStreetMap contributors, ODbL.
"""
import json, sys, time, urllib.request, urllib.parse, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
RES = ROOT / "AutreyMillSentry" / "Resources"
UA = "AutreyMillSentry/0.1 (student project, jeetusk08@gmail.com)"

# Nominatim result for way 34787528 (natural=wood "Autrey Mill Nature Preserve"):
# bbox lat 34.0152237..34.0246030, lon -84.2350558..-84.2301030. Add a margin.
MARGIN = 0.0035
S, N = 34.0152237 - MARGIN, 34.0246030 + MARGIN
W, E = -84.2350558 - MARGIN, -84.2301030 + MARGIN
BBOX = f"{S},{W},{N},{E}"

QUERY = f"""
[out:json][timeout:90];
(
  way["highway"]({BBOX});
  way["natural"]({BBOX});
  way["leisure"]({BBOX});
  relation["leisure"]({BBOX});
  way["boundary"]({BBOX});
  relation["boundary"="protected_area"]({BBOX});
  way["waterway"]({BBOX});
  way["water"]({BBOX});
  way["building"]({BBOX});
  node["amenity"]({BBOX});
  way["amenity"]({BBOX});
  node["tourism"]({BBOX});
  way["tourism"]({BBOX});
  node["leisure"]({BBOX});
  way["man_made"]({BBOX});
  node["man_made"]({BBOX});
  node["historic"]({BBOX});
  way["historic"]({BBOX});
  node["information"]({BBOX});
  node["natural"]({BBOX});
  way["bridge"]({BBOX});
  node["barrier"]({BBOX});
  node["entrance"]({BBOX});
);
out body geom;
"""

def fetch():
    RAW.mkdir(parents=True, exist_ok=True)
    out = RAW / "overpass.json"
    if out.exists() and "--refresh" not in sys.argv:
        print("using cached", out)
        return json.loads(out.read_text())
    data = urllib.parse.urlencode({"data": QUERY}).encode()
    for attempt in range(4):
        try:
            req = urllib.request.Request("https://overpass-api.de/api/interpreter", data=data, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=120) as r:
                body = r.read()
            j = json.loads(body)
            out.write_bytes(body)
            print("saved", out, len(j.get("elements", [])), "elements")
            return j
        except Exception as e:
            print("attempt", attempt, "failed:", e)
            time.sleep(10 * (attempt + 1))
    raise SystemExit("Overpass failed")

def way_coords(el):
    return [[p["lon"], p["lat"]] for p in el.get("geometry", [])]

def feature(geom_type, coords, props):
    return {"type": "Feature", "geometry": {"type": geom_type, "coordinates": coords}, "properties": props}

def props_for(el, keep):
    t = el.get("tags", {})
    p = {"osm_type": el["type"], "osm_id": el["id"]}
    for k in keep:
        if k in t:
            p[k] = t[k]
    return p

def convert(j):
    trails, boundary, water, poi, buildings = [], [], [], [], []
    for el in j["elements"]:
        t = el.get("tags", {})
        typ = el["type"]
        if typ == "way" and "highway" in t:
            kind = t["highway"]
            if kind in ("path", "footway", "track", "steps", "bridleway", "cycleway", "pedestrian"):
                p = props_for(el, ["name", "highway", "surface", "bridge", "sac_scale", "trail_visibility", "width", "lit", "informal", "access", "operator"])
                p["kind"] = "trail"
                trails.append(feature("LineString", way_coords(el), p))
            else:
                p = props_for(el, ["name", "highway", "surface", "service", "access"])
                p["kind"] = "road"
                trails.append(feature("LineString", way_coords(el), p))
        elif typ == "way" and "waterway" in t:
            p = props_for(el, ["name", "waterway", "intermittent"])
            water.append(feature("LineString", way_coords(el), p))
        elif typ == "way" and (t.get("natural") == "water" or "water" in t):
            c = way_coords(el)
            p = props_for(el, ["name", "natural", "water"])
            water.append(feature("Polygon", [c], p))
        elif typ == "way" and (t.get("natural") == "wood" or t.get("leisure") in ("nature_reserve", "park") or t.get("boundary") in ("protected_area", "national_park")):
            c = way_coords(el)
            p = props_for(el, ["name", "natural", "leisure", "boundary", "protect_class", "operator", "website", "wikidata"])
            if c and c[0] == c[-1]:
                boundary.append(feature("Polygon", [c], p))
            else:
                boundary.append(feature("LineString", c, p))
        elif typ == "relation" and (t.get("leisure") in ("nature_reserve", "park") or t.get("boundary") == "protected_area"):
            p = props_for(el, ["name", "leisure", "boundary", "operator", "website", "wikidata"])
            p["note"] = "relation; members not expanded"
            boundary.append(feature("Point", [0, 0], p))
        elif typ == "way" and "building" in t:
            c = way_coords(el)
            p = props_for(el, ["name", "building", "amenity", "tourism", "historic", "addr:housenumber", "addr:street"])
            p["kind"] = "building"
            buildings.append(feature("Polygon", [c], p))
        elif typ == "way" and (t.get("amenity") or t.get("leisure") or t.get("tourism") or t.get("man_made") or t.get("historic")):
            c = way_coords(el)
            p = props_for(el, ["name", "amenity", "leisure", "tourism", "man_made", "historic", "parking", "access", "capacity"])
            p["kind"] = t.get("amenity") or t.get("leisure") or t.get("tourism") or t.get("man_made") or t.get("historic")
            if c and c[0] == c[-1] and len(c) >= 4:
                poi.append(feature("Polygon", [c], p))
            else:
                poi.append(feature("LineString", c, p))
        elif typ == "node":
            if not t:
                continue
            p = props_for(el, ["name", "amenity", "tourism", "leisure", "man_made", "historic", "information", "natural", "barrier", "entrance", "shelter_type", "description", "board_type"])
            p["kind"] = t.get("amenity") or t.get("tourism") or t.get("leisure") or t.get("man_made") or t.get("historic") or t.get("information") or t.get("natural") or t.get("barrier") or t.get("entrance") or "node"
            poi.append(feature("Point", [el["lon"], el["lat"]], p))
    RES.mkdir(parents=True, exist_ok=True)
    def write(name, feats):
        fc = {"type": "FeatureCollection", "attribution": "Map data (c) OpenStreetMap contributors, ODbL 1.0. https://www.openstreetmap.org/copyright", "features": feats}
        (RES / name).write_text(json.dumps(fc, indent=1))
        print(name, len(feats), "features")
    write("trails.geojson", trails)
    write("boundary.geojson", boundary)
    write("waterways.geojson", water)
    write("poi.geojson", poi + buildings)

if __name__ == "__main__":
    convert(fetch())
