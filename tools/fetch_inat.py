#!/usr/bin/env python3
"""iNaturalist dataset builder for Autrey Mill Sentry.

Usage:
  python3 -I tools/fetch_inat.py survey      # resolve taxa, count licensed Georgia/SE photos -> data/raw/inat_survey.json
  python3 -I tools/fetch_inat.py download    # download images for the selected classes -> data/images/<class>/
  python3 -I tools/fetch_inat.py all

Rules: API v1, research grade, photos licensed CC0 / CC-BY / CC-BY-NC only, ~1 request/sec, descriptive User-Agent,
everything cached. Every image is logged in data/attribution.csv. Images are never committed or redistributed.
"""
import csv, json, os, sys, time, threading, pathlib, random, urllib.request, urllib.parse
from concurrent.futures import ThreadPoolExecutor

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
IMG = ROOT / "data" / "images"
CACHE = ROOT / "data" / "cache"
MODEL = ROOT / "model"
UA = "AutreyMillSentry/0.1 (student project, jeetusk08@gmail.com)"
API = "https://api.inaturalist.org/v1"
ALLOWED = {"cc0", "cc-by", "cc-by-nc"}
GEORGIA = 23  # iNaturalist place_id for Georgia, US (verified via /v1/places/autocomplete on 2026-10-12)
SE_STATES = ["Alabama", "South Carolina", "North Carolina", "Tennessee", "Florida"]
US = 1

# ---- class definitions -------------------------------------------------------------------------
# Tier 1: documented at Autrey Mill (preserve's own 2012 post, 12 of its 14 that are on the Georgia Invasive
# Species Council plant list) + the 3 most common north Georgia forest invasives. Verified on
# https://gainvasivespeciescouncil.org/list/invasive-plants/ (fetched 2026-10-12).
TIER1 = {
    "ligustrum_sinense": "Ligustrum sinense",          # Chinese privet (AM)
    "mahonia_bealei": "Mahonia bealei",                # leatherleaf mahonia / Oregon grape holly (AM)
    "lonicera_japonica": "Lonicera japonica",          # Japanese honeysuckle (AM)
    "wisteria_sinensis": "Wisteria sinensis",          # Chinese wisteria (AM)
    "vinca_minor": "Vinca minor",                      # common periwinkle (AM)
    "elaeagnus_umbellata": "Elaeagnus umbellata",      # autumn olive (AM)
    "elaeagnus_pungens": "Elaeagnus pungens",          # thorny olive (AM)
    "rosa_multiflora": "Rosa multiflora",              # multiflora rose (AM)
    "hedera_helix": "Hedera helix",                    # English ivy (AM)
    "albizia_julibrissin": "Albizia julibrissin",      # mimosa (AM)
    "paulownia_tomentosa": "Paulownia tomentosa",      # princess tree (AM)
    "microstegium_vimineum": "Microstegium vimineum",  # Japanese stiltgrass (north GA)
    "pueraria_montana": "Pueraria montana",            # kudzu (north GA)
    "nandina_domestica": "Nandina domestica",          # nandina (north GA)
}
# Native look-alikes and safety natives (never reported as invasive).
NATIVE = {
    "lonicera_sempervirens": "Lonicera sempervirens",      # coral honeysuckle vs Japanese honeysuckle
    "wisteria_frutescens": "Wisteria frutescens",          # American wisteria vs Chinese wisteria
    "viburnum_acerifolium": "Viburnum acerifolium",        # mapleleaf viburnum vs privet
    "viburnum_dentatum": "Viburnum dentatum",              # arrowwood viburnum vs privet
    "ilex_opaca": "Ilex opaca",                            # American holly vs mahonia / Chinese holly
    "toxicodendron_radicans": "Toxicodendron radicans",    # poison ivy vs English ivy (safety)
    "parthenocissus_quinquefolia": "Parthenocissus quinquefolia",  # Virginia creeper vs English ivy
    "vitis_rotundifolia": "Vitis rotundifolia",            # muscadine vs kudzu
    "rosa_carolina": "Rosa carolina",                      # Carolina rose vs multiflora rose
    "rubus_argutus": "Rubus argutus",                      # sawtooth blackberry vs multiflora rose
    "mitchella_repens": "Mitchella repens",                # partridgeberry vs periwinkle
    "catalpa_bignonioides": "Catalpa bignonioides",        # southern catalpa vs princess tree
    "chasmanthium_latifolium": "Chasmanthium latifolium",  # river oats vs stiltgrass
    "smilax_rotundifolia": "Smilax rotundifolia",          # greenbrier (common native vine)
}
# Common native plants of the preserve's own neighbourhood: the most-observed research-grade plant species on
# iNaturalist within 4 km of Autrey Mill (data/raw/inat_local_species.json, 19 Oct 2026), natives only, plus a few
# Piedmont staples. Named classes so the scanner can say 'sweetgum, not a target' instead of guessing. Values are
# (iNaturalist accepted name, taxon id, common name).
LOCAL_NATIVE = {
    "liquidambar_styraciflua": ('Liquidambar styraciflua', 49658, 'American sweetgum'),
    "polystichum_acrostichoides": ('Polystichum acrostichoides', 54412, 'Christmas fern'),
    "podophyllum_peltatum": ('Podophyllum peltatum', 49288, 'mayapple'),
    "magnolia_grandiflora": ('Magnolia grandiflora', 83074, 'southern magnolia'),
    "phoradendron_leucarpum": ('Phoradendron leucarpum', 49668, 'American Mistletoe'),
    "liriodendron_tulipifera": ('Liriodendron tulipifera', 53582, 'American tuliptree'),
    "trillium_cuneatum": ('Trillium cuneatum', 123634, 'Little Sweet Betsy'),
    "andersonglossum_virginianum": ('Andersonglossum virginianum', 769248, 'wild comfrey'),
    "phytolacca_americana": ('Phytolacca americana', 48599, 'American pokeweed'),
    "fagus_grandifolia": ('Fagus grandifolia', 49202, 'American beech'),
    "packera_glabella": ('Packera glabella', 54921, 'Butterweed'),
    "verbesina_occidentalis": ('Verbesina occidentalis', 136384, 'Yellow Crownbeard'),
    "asimina_parviflora": ('Asimina parviflora', 158769, 'Small-Flower Pawpaw'),
    "cornus_florida": ('Cornus florida', 54777, 'flowering dogwood'),
    "bignonia_capreolata": ('Bignonia capreolata', 67823, 'cross vine'),
    "solanum_carolinense": ('Solanum carolinense', 52899, 'Carolina horsenettle'),
    "campsis_radicans": ('Campsis radicans', 75995, 'American trumpet vine'),
    "diospyros_virginiana": ('Diospyros virginiana', 83435, 'American persimmon'),
    "tipularia_discolor": ('Tipularia discolor', 121490, 'crane-fly orchid'),
    "acer_rubrum": ('Acer rubrum', 48098, 'red maple'),
    "eupatorium_serotinum": ('Eupatorium serotinum', 52934, 'late boneset'),
    "prunus_serotina": ('Prunus serotina', 54834, 'black cherry'),
    "euonymus_americanus": ('Euonymus americanus', 83150, 'strawberry bush'),
    "thalictrum_thalictroides": ('Thalictrum thalictroides', 118548, 'rue anemone'),
    "erechtites_hieraciifolius": ('Erechtites hieraciifolius', 130888, 'American burnweed'),
    "eupatorium_capillifolium": ('Eupatorium capillifolium', 131154, 'dogfennel'),
    "athyrium_asplenioides": ('Athyrium asplenioides', 204244, 'southern lady fern'),
    "cypripedium_acaule": ('Cypripedium acaule', 47588, "pink lady's slipper"),
    "acer_negundo": ('Acer negundo', 47726, 'box elder'),
    "callicarpa_americana": ('Callicarpa americana', 49193, 'American beautyberry'),
    "chimaphila_maculata": ('Chimaphila maculata', 82358, 'striped wintergreen'),
    "woodwardia_areolata": ('Woodwardia areolata', 118731, 'netted chain fern'),
    "cercis_canadensis": ('Cercis canadensis', 48502, 'eastern redbud'),
    "quercus_nigra": ('Quercus nigra', 53640, 'water oak'),
    "carpinus_caroliniana": ('Carpinus caroliniana', 54768, 'American hornbeam'),
    "lindera_benzoin": ('Lindera benzoin', 54793, 'northern spicebush'),
    "erigeron_philadelphicus": ('Erigeron philadelphicus', 67820, 'Philadelphia fleabane'),
    "aesculus_pavia": ('Aesculus pavia', 81708, 'Red Buckeye'),
    "asplenium_platyneuron": ('Asplenium platyneuron', 122056, 'ebony spleenwort'),
    "diodia_virginiana": ('Diodia virginiana', 131003, 'buttonweed'),
    "elephantopus_tomentosus": ('Elephantopus tomentosus', 152133, "common elephant's-foot"),
    "amauropelta_noveboracensis": ('Amauropelta noveboracensis', 1398911, 'New York fern'),
    "asarum_arifolium": ('Asarum arifolium', 1455147, 'Little Brown Jugs'),
    "kalmia_latifolia": ('Kalmia latifolia', 49397, 'mountain laurel'),
    "asimina_triloba": ('Asimina triloba', 50897, 'common pawpaw'),
    "passiflora_incarnata": ('Passiflora incarnata', 51453, 'purple passionflower'),
    "magnolia_tripetala": ('Magnolia tripetala', 84790, 'umbrella magnolia'),
    "ambrosia_artemisiifolia": ('Ambrosia artemisiifolia', 53587, 'common ragweed'),
    "juglans_nigra": ('Juglans nigra', 54504, 'eastern black walnut'),
    "sassafras_albidum": ('Sassafras albidum', 54795, 'sassafras'),
    "pinus_taeda": ('Pinus taeda', 59921, 'loblolly pine'),
    "goodyera_pubescens": ('Goodyera pubescens', 62406, 'downy rattlesnake plantain'),
    "packera_anonyma": ('Packera anonyma', 67825, "Small's ragwort"),
    "oxalis_violacea": ('Oxalis violacea', 81796, 'violet woodsorrel'),
    "onoclea_sensibilis": ('Onoclea sensibilis', 82576, 'sensitive fern'),
    "hydrangea_quercifolia": ('Hydrangea quercifolia', 83156, 'oakleaf hydrangea'),
    "verbesina_alternifolia": ('Verbesina alternifolia', 117442, 'Wingstem'),
    "ilex_vomitoria": ('Ilex vomitoria', 119955, 'Yaupon Holly'),
    "houstonia_pusilla": ('Houstonia pusilla', 125101, 'tiny bluet'),
    "melothria_pendula": ('Melothria pendula', 131557, 'creeping cucumber'),
    "persicaria_virginiana": ('Persicaria virginiana', 144047, 'American jumpseed'),
    "arnoglossum_atriplicifolium": ('Arnoglossum atriplicifolium', 146715, 'pale Indian plantain'),
    "pleopeltis_michauxiana": ('Pleopeltis michauxiana', 698726, 'resurrection fern'),
    "acer_floridanum": ('Acer floridanum', 48079, 'southern sugar maple'),
    "quercus_rubra": ('Quercus rubra', 49005, 'northern red oak'),
    "quercus_falcata": ('Quercus falcata', 61324, 'southern red oak'),
    "sambucus_canadensis": ('Sambucus canadensis', 84300, 'American black elderberry'),
    "gelsemium_sempervirens": ('Gelsemium sempervirens', 83070, 'yellow jessamine'),
    "vaccinium_arboreum": ('Vaccinium arboreum', 81818, 'sparkleberry'),
    "juniperus_virginiana": ('Juniperus virginiana', 49399, 'eastern redcedar'),
    "impatiens_capensis": ('Impatiens capensis', 47888, 'common jewelweed'),
    "quercus_alba": ('Quercus alba', 54779, 'white oak'),
    "arundinaria_gigantea": ('Arundinaria gigantea', 121747, 'river cane'),
    "vitis_aestivalis": ('Vitis aestivalis', 128931, 'summer grape'),
}
# Tier 2 candidates: the rest of the GISC plant list. Excluded by hand: submerged aquatics (not phone-scannable),
# turf grasses, and genus-only entries. The survey keeps those with >= MIN_T2 licensed photos.
TIER2_CANDIDATES = [
    "Ailanthus altissima", "Alternanthera philoxeroides", "Dryopteris erythrosora", "Eichhornia crassipes",
    "Lespedeza bicolor", "Lespedeza cuneata", "Lygodium japonicum", "Melia azedarach", "Murdannia keisak",
    "Triadica sebifera", "Ardisia crenata", "Cinnamomum camphora", "Crotalaria lanceolata", "Crotalaria pallida",
    "Crotalaria spectabilis", "Dioscorea polystachya", "Leucanthemum vulgare", "Ligustrum lucidum", "Lonicera maackii",
    "Miscanthus sinensis", "Myriophyllum aquaticum", "Nasturtium officinale", "Phyllostachys aurea", "Sesbania punicea",
    "Spiraea japonica", "Tamarix gallica", "Vinca major", "Vitex rotundifolia", "Ajuga reptans", "Alternanthera sessilis",
    "Ampelopsis glandulosa", "Anthoxanthum odoratum", "Arundo donax", "Berberis thunbergii", "Broussonetia papyrifera",
    "Carduus nutans", "Centaurea cyanus", "Citrus trifoliata", "Clematis terniflora", "Colocasia esculenta",
    "Daucus carota", "Dioscorea alata", "Dioscorea bulbifera", "Euonymus fortunei", "Hemerocallis fulva",
    "Hibiscus syriacus", "Lantana camara", "Lespedeza thunbergii", "Ligustrum japonicum", "Liriope muscari",
    "Lonicera fragrantissima", "Melinis repens", "Mentha x piperita", "Morus alba", "Mosla dianthera",
    "Panicum repens", "Paspalum urvillei", "Perilla frutescens", "Persicaria maculosa", "Phragmites australis",
    "Pyrus calleryana", "Rottboellia cochinchinensis", "Rubus armeniacus", "Securigera varia", "Solanum viarum",
    "Sorghum halepense", "Vernicia fordii", "Akebia quinata", "Allium vineale", "Alysicarpus vaginalis",
    "Artemisia vulgaris", "Bidens pilosa", "Bromus secalinus", "Bromus tectorum", "Cirsium vulgare",
    "Commelina benghalensis", "Cytisus scoparius", "Euonymus alatus", "Fatoua villosa", "Firmiana simplex",
    "Ilex cornuta", "Ilex crenata", "Indigofera hirsuta", "Ipomoea coccinea", "Ipomoea purpurea",
    "Jacquemontia tamnifolia", "Kummerowia stipulacea", "Kummerowia striata", "Liriope spicata", "Orobanche minor",
    "Paspalum quadrifarium", "Persicaria longiseta", "Pyracantha coccinea", "Quercus acutissima",
    "Reynoutria sachalinensis", "Rosa laevigata", "Rubus phoenicolasius", "Setaria faberi", "Setaria pumila",
    "Setaria viridis", "Sonchus asper", "Sonchus oleraceus", "Torilis arvensis", "Verbascum thapsus",
    "Verbena bonariensis", "Verbena incompta", "Wisteria floribunda", "Buddleja davidii",
    # Species of Concern
    "Alliaria petiolata", "Achyranthes japonica", "Arthraxon hispidus", "Celastrus orbiculatus", "Imperata cylindrica",
    "Lygodium microphyllum", "Paederia foetida", "Reynoutria japonica", "Schinus terebinthifolia",
]
EXCLUDED_T2 = {  # name: reason (documented in model/CLASSES.md)
    "Hydrilla verticillata": "submerged aquatic", "Egeria densa": "submerged aquatic", "Myriophyllum spicatum": "submerged aquatic",
    "Najas minor": "submerged aquatic", "Potamogeton crispus": "submerged aquatic", "Limnophila sessiliflora": "submerged aquatic",
    "Marsilea minuta": "aquatic fern, tiny", "Salvinia minima": "floating aquatic", "Salvinia molesta": "floating aquatic",
    "Cynodon dactylon": "turf grass", "Festuca arundinacea": "turf grass", "Paspalum notatum": "turf grass",
    "Poa annua": "turf grass", "Eragrostis curvula": "roadside grass", "Verbascum": "genus-only entry (used Verbascum thapsus)",
}
MIN_T2 = 80
TARGETS = {"tier1": 600, "native": 350, "tier2": 220, "other_plant": 3200, "not_plant": 1500}
PHOTOS_PER_OBS = {"tier1": 2, "native": 2, "tier2": 2, "other_plant": 1, "not_plant": 1}

# ---- http -------------------------------------------------------------------------------------
_lock = threading.Lock()
_last = [0.0]

def api_get(path, params):
    """GET with on-disk cache and a 1 request/second limit."""
    CACHE.mkdir(parents=True, exist_ok=True)
    url = f"{API}{path}?{urllib.parse.urlencode(params)}"
    key = CACHE / (urllib.parse.quote(url, safe="")[:200] + "_" + str(abs(hash(url)) % 10**8) + ".json")
    if key.exists():
        return json.loads(key.read_text())
    attempt = 0
    while True:
        with _lock:
            wait = 1.05 - (time.time() - _last[0])
            if wait > 0:
                time.sleep(wait)
            _last[0] = time.time()
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=60) as r:
                body = r.read()
            j = json.loads(body)
            key.write_bytes(body)
            return j
        except Exception as e:
            attempt += 1
            delay = min(900, 10 * attempt * attempt)   # 10 s, 40 s, 90 s ... up to 15 min: the API has maintenance windows
            print(f"  api retry {attempt} ({e}); sleeping {delay}s", flush=True)
            if attempt >= 40:
                raise RuntimeError("API failed: " + url)
            time.sleep(delay)

SYNONYMS = {  # GISC/preserve name -> iNaturalist accepted name
    "Mahonia bealei": "Berberis bealei",
    "Pueraria montana": "Pueraria montana",
    "Eichhornia crassipes": "Pontederia crassipes",
    "Securigera varia": "Securigera varia",
    "Citrus trifoliata": "Citrus trifoliata",
    "Mentha x piperita": "Mentha × piperita",
    "Persicaria maculosa": "Persicaria maculosa",
    "Fatoua villosa": "Fatoua villosa",
}

def resolve_taxon(name):
    name = SYNONYMS.get(name, name)
    j = api_get("/taxa/autocomplete", {"q": name, "per_page": 10})
    for r in j.get("results", []):
        if r.get("rank") == "species" and r.get("name", "").lower() == name.lower():
            return r
    for r in j.get("results", []):  # accept genus/species match on first word pair
        if r.get("name", "").lower().startswith(name.lower().split(" x ")[0]):
            return r
    return None

def resolve_place(name):
    j = api_get("/places/autocomplete", {"q": name, "per_page": 10})
    for r in j.get("results", []):
        if r.get("name") == name and r.get("admin_level") == 10:
            return r["id"]
    return None

def count_obs(taxon_id, place_id):
    j = api_get("/observations", {"taxon_id": taxon_id, "place_id": place_id, "quality_grade": "research",
                                  "photos": "true", "photo_license": "cc0,cc-by,cc-by-nc", "per_page": 0})
    return j.get("total_results", 0)

# ---- survey -----------------------------------------------------------------------------------
def survey():
    RAW.mkdir(parents=True, exist_ok=True)
    out = RAW / "inat_survey.json"
    res = json.loads(out.read_text()) if out.exists() else {"places": {}, "taxa": {}}
    for s in SE_STATES:
        if s not in res["places"]:
            res["places"][s] = resolve_place(s)
            print("place", s, res["places"][s], flush=True)
    se_ids = [res["places"][s] for s in SE_STATES if res["places"][s]]
    se_param = ",".join(str(i) for i in se_ids)
    groups = [("tier1", TIER1), ("native", NATIVE), ("tier2", {n.lower().replace(" ", "_").replace("_x_", "_"): n for n in TIER2_CANDIDATES}),
              ("native", LOCAL_NATIVE)]
    for tier, d in groups:
        for key, spec in d.items():
            if key in res["taxa"] and res["taxa"][key].get("taxon_id"):
                continue
            if isinstance(spec, tuple):   # known taxon id: no autocomplete round trip
                name, tid, com = spec
                t = {"id": tid, "name": name, "preferred_common_name": com}
            else:
                name = spec
                t = resolve_taxon(name)
            if not t:
                res["taxa"][key] = {"name": name, "tier": tier, "taxon_id": None, "ga": 0, "se": 0, "us": 0}
                print("NOT FOUND", name, flush=True)
                out.write_text(json.dumps(res, indent=1))
                continue
            ga = count_obs(t["id"], GEORGIA)
            se = count_obs(t["id"], se_param)
            us = count_obs(t["id"], US) if ga + se < 400 else None
            res["taxa"][key] = {"name": name, "tier": tier, "taxon_id": t["id"], "inat_name": t["name"],
                                "common": t.get("preferred_common_name"), "ga": ga, "se": se, "us": us}
            print(f"{tier:7s} {name:32s} id={t['id']:<8} GA={ga:<6} SE={se:<6} US={us}", flush=True)
            out.write_text(json.dumps(res, indent=1))
    out.write_text(json.dumps(res, indent=1))
    write_classes(res)

def write_classes(res):
    classes = []
    for key, t in res["taxa"].items():
        if not t.get("taxon_id"):
            continue
        total = t["ga"] + t["se"]
        if t["tier"] == "tier2" and total < MIN_T2:
            continue
        classes.append({"label": key, "tier": t["tier"], "taxon_id": t["taxon_id"], "name": t["name"],
                        "common": t.get("common"), "ga": t["ga"], "se": t["se"]})
    classes.append({"label": "other_plant", "tier": "other", "taxon_id": 47126, "name": "Plantae (random Georgia plants, excluding all classes above)"})
    classes.append({"label": "not_plant", "tier": "other", "taxon_id": None, "name": "Fungi, insects, birds, reptiles, mammals and other non-plant observations in Georgia"})
    MODEL.mkdir(exist_ok=True)
    (MODEL / "classes.json").write_text(json.dumps({"generated": time.strftime("%Y-%m-%d"), "min_tier2_images": MIN_T2, "classes": classes}, indent=1))
    print("classes:", len(classes), flush=True)

# ---- download ---------------------------------------------------------------------------------
_attr_lock = threading.Lock()

def attribution_writer():
    path = ROOT / "data" / "attribution.csv"
    new = not path.exists()
    f = open(path, "a", newline="")
    w = csv.writer(f)
    if new:
        w.writerow(["class", "observation_id", "photo_id", "observer", "license", "photo_url", "observation_url", "observed_on", "place_guess"])
    return f, w

def fetch_photo(url, dest):
    if dest.exists():
        return True
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                data = r.read()
            if len(data) < 2000:
                return False
            dest.write_bytes(data)
            time.sleep(0.15)
            return True
        except Exception as e:
            time.sleep(2 * (attempt + 1))
    return False

def iter_observations(params, limit):
    """Page through /observations with id_above pagination, newest-first reversed to a stable order."""
    seen = 0
    id_above = 0
    while seen < limit:
        p = dict(params); p.update({"per_page": 200, "order_by": "id", "order": "asc", "id_above": id_above})
        j = api_get("/observations", p)
        results = j.get("results", [])
        if not results:
            return
        for o in results:
            yield o
            seen += 1
            if seen >= limit:
                return
        id_above = results[-1]["id"]

def download():
    classes = json.loads((MODEL / "classes.json").read_text())["classes"]
    survey_res = json.loads((RAW / "inat_survey.json").read_text())
    se_param = ",".join(str(survey_res["places"][s]) for s in SE_STATES if survey_res["places"][s])
    all_taxa = [c["taxon_id"] for c in classes if c["taxon_id"] and c["label"] not in ("other_plant",)]
    f, w = attribution_writer()
    done_photos = set()
    attr_path = ROOT / "data" / "attribution.csv"
    with open(attr_path) as fr:
        for row in csv.DictReader(fr):
            done_photos.add(row["photo_id"])
    pool = ThreadPoolExecutor(max_workers=4)
    for c in classes:
        label, tier = c["label"], c["tier"]
        target = TARGETS["other_plant"] if label == "other_plant" else TARGETS["not_plant"] if label == "not_plant" else TARGETS[tier]
        per_obs = PHOTOS_PER_OBS.get(tier, 1) if label not in ("other_plant", "not_plant") else 1
        d = IMG / label
        d.mkdir(parents=True, exist_ok=True)
        have = len(list(d.glob("*.jpg")))
        if have >= target:
            print(f"[{label}] already {have} images", flush=True)
            continue
        print(f"[{label}] need {target}, have {have}", flush=True)
        base = {"quality_grade": "research", "photos": "true", "photo_license": "cc0,cc-by,cc-by-nc"}
        if label == "other_plant":
            base.update({"taxon_id": 47126, "without_taxon_id": ",".join(map(str, all_taxa)), "rank": "species"})
            place_plan = [(GEORGIA, target), (se_param, target), (US, target)]
        elif label == "not_plant":
            base.update({"iconic_taxa": "Fungi,Insecta,Aves,Reptilia,Amphibia,Mammalia,Arachnida,Mollusca"})
            place_plan = [(GEORGIA, target)]
        else:
            base.update({"taxon_id": c["taxon_id"]})
            place_plan = [(GEORGIA, target), (se_param, target), (US, target)]
        seen_obs = set()
        futures = []
        count = have
        for place_id, cap in place_plan:
            if count >= target:
                break
            p = dict(base); p["place_id"] = place_id
            # how many observations to walk: enough to reach the target given per_obs photos each
            for o in iter_observations(p, limit=max(50, int((target - count) / max(per_obs, 1) * 1.2) + 50)):
                if count >= target:
                    break
                if o["id"] in seen_obs:
                    continue
                seen_obs.add(o["id"])
                user = (o.get("user") or {}).get("login", "")
                taken = 0
                for ph in o.get("photos", []):
                    lic = (ph.get("license_code") or "").lower()
                    if lic not in ALLOWED:
                        continue
                    pid = str(ph["id"])
                    if pid in done_photos:
                        continue
                    url = ph["url"].replace("square", "medium")
                    dest = d / f"{o['id']}_{pid}.jpg"
                    def job(url=url, dest=dest, row=[label, o["id"], pid, user, lic, url, f"https://www.inaturalist.org/observations/{o['id']}", o.get("observed_on"), o.get("place_guess")]):
                        if fetch_photo(url, dest):
                            with _attr_lock:
                                w.writerow(row); f.flush()
                            return True
                        return False
                    futures.append(pool.submit(job))
                    done_photos.add(pid)
                    taken += 1; count += 1
                    if taken >= per_obs or count >= target:
                        break
            # drain periodically so the count is honest
            for fut in futures:
                if not fut.result():
                    count -= 1
            futures = []
        print(f"[{label}] done: {len(list(d.glob('*.jpg')))} images", flush=True)
    # Cultivated / house / garden plants into other_plant (what people point phones at indoors and in yards).
    d = IMG / "other_plant"; d.mkdir(parents=True, exist_ok=True)
    have_cult = len(list(d.glob("cult_*.jpg")))
    target_cult = 900
    if have_cult < target_cult:
        print(f"[other_plant/cultivated] need {target_cult}, have {have_cult}", flush=True)
        count = have_cult
        for place_id in (GEORGIA, se_param, US):
            if count >= target_cult: break
            p = {"taxon_id": 47126, "without_taxon_id": ",".join(map(str, all_taxa)), "captive": "true", "photos": "true",
                 "photo_license": "cc0,cc-by,cc-by-nc", "place_id": place_id, "rank": "species"}
            futures = []
            for o in iter_observations(p, limit=max(50, int((target_cult - count) * 1.3) + 50)):
                if count >= target_cult: break
                user = (o.get("user") or {}).get("login", "")
                for ph in o.get("photos", [])[:1]:
                    lic = (ph.get("license_code") or "").lower()
                    if lic not in ALLOWED: continue
                    pid = str(ph["id"])
                    if pid in done_photos: continue
                    url = ph["url"].replace("square", "medium")
                    dest = d / f"cult_{o['id']}_{pid}.jpg"
                    def job(url=url, dest=dest, row=["other_plant", o["id"], pid, user, lic, url, f"https://www.inaturalist.org/observations/{o['id']}", o.get("observed_on"), o.get("place_guess")]):
                        if fetch_photo(url, dest):
                            with _attr_lock:
                                w.writerow(row); f.flush()
                            return True
                        return False
                    futures.append(pool.submit(job)); done_photos.add(pid); count += 1
            for fut in futures:
                if not fut.result(): count -= 1
        print(f"[other_plant/cultivated] done: {len(list(d.glob('cult_*.jpg')))} images", flush=True)
    pool.shutdown(wait=True)
    f.close()

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "all"
    if cmd in ("survey", "all"):
        survey()
    if cmd in ("download", "all"):
        download()
