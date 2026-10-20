#!/usr/bin/env python3
"""Write AutreyMillSentry/Resources/local_species.json: the common native plants of the preserve's neighbourhood that the
classifier knows by name (tier "native", never reported). Entries come from model/classes.json (labels, names, iNaturalist
ids) filtered to the labels the bundled model actually outputs (Resources/labels.json) when that file exists.
Hand-written recognition notes live in LOCAL_NOTES below; species without notes get an honest generic line."""
import json, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / "AutreyMillSentry" / "Resources"
classes = json.loads((ROOT / "model/classes.json").read_text())["classes"]
builtin = {"lonicera_sempervirens","wisteria_frutescens","viburnum_acerifolium","viburnum_dentatum","ilex_opaca","toxicodendron_radicans",
           "parthenocissus_quinquefolia","vitis_rotundifolia","rosa_carolina","rubus_argutus","mitchella_repens","catalpa_bignonioides",
           "chasmanthium_latifolium","smilax_rotundifolia"}
labels_file = RES / "labels.json"
known = set(json.loads(labels_file.read_text())["labels"]) if labels_file.exists() else None
new_labels = {c["label"] for c in classes if c["tier"] == "native" and c["label"] not in builtin}
if known is not None and not (known & new_labels):
    known = None   # the bundled model predates these classes: list them all; the filter applies once v4 ships
LOCAL_NOTES = {  # label: (how to recognise, what to photograph). Plain field marks only.
 "liquidambar_styraciflua": ("Star-shaped leaves with five pointed lobes, fragrant when crushed; spiky round 'gumballs' hang from the twigs and litter the ground.", "One leaf flat on, and a gumball if you can find one."),
 "polystichum_acrostichoides": ("Evergreen fern in clumps on shady slopes. Each leaflet has a small ear at its base, like a Christmas stocking.", "One frond with the stocking-shaped leaflets."),
 "podophyllum_peltatum": ("Spring wildflower: one or two big umbrella-shaped leaves on a single stalk, a white flower hidden underneath.", "The umbrella leaf from the side."),
 "magnolia_grandiflora": ("Big glossy evergreen leaves, rusty-brown and fuzzy underneath; huge white flowers in early summer and cone-like seed heads.", "A leaf showing the brown underside."),
 "liriodendron_tulipifera": ("Tall straight tree. Leaves look like a tulip outline with a notched, flat tip; tulip-shaped green-and-orange flowers in spring.", "One leaf flat on."),
 "trillium_cuneatum": ("Spring wildflower: one whorl of three mottled leaves topped by a dark maroon flower that stays closed like a candle.", "The three leaves and flower from above."),
 "phytolacca_americana": ("Tall weedy plant with smooth magenta stems, large soft leaves, and drooping clusters of shiny purple-black berries. Toxic: do not eat.", "The stem colour and a berry cluster."),
 "fagus_grandifolia": ("Smooth grey bark like an elephant's leg; oval leaves with straight parallel veins ending in small teeth; papery pale leaves often hang on all winter.", "The bark and one leaf."),
 "cornus_florida": ("Small understory tree. Leaves in opposite pairs with veins that curve toward the tip; big four-petalled white blooms in spring; red berries in autumn.", "A twig with the opposite leaves."),
 "bignonia_capreolata": ("Climbing vine with leaves in pairs ending in a tendril; orange-red trumpet flowers in spring.", "A leaf pair with its tendril."),
 "campsis_radicans": ("Vigorous vine with compound leaves of toothed leaflets and big orange trumpet flowers in summer.", "A flower and one compound leaf."),
 "diospyros_virginiana": ("Tree with dark bark broken into square blocks like alligator skin; oval glossy leaves; orange fruit in autumn.", "The blocky bark and a leaf."),
 "acer_rubrum": ("Maple with three- to five-lobed leaves on red stalks, pale underneath; red flowers and winged seeds in early spring.", "One leaf flat on, showing the red stalk."),
 "prunus_serotina": ("Tree with narrow glossy leaves with fine teeth; crushed twigs smell of almond; dark scaly bark; white flower spikes then small black cherries.", "A twig with leaves."),
 "euonymus_americanus": ("Open shrub with green four-angled stems and opposite leaves; the bumpy red seed capsules split open to show orange seeds ('hearts-a-bustin').", "The green stems and a capsule if present."),
 "acer_negundo": ("Maple that does not look like one: compound leaves with three to five leaflets, opposite on green twigs. Often mistaken for poison ivy.", "A twig showing leaves in opposite pairs."),
 "callicarpa_americana": ("Shrub with opposite oval leaves and tight clusters of bright magenta berries around the stem in autumn.", "A stem with the berry clusters."),
 "chimaphila_maculata": ("Small evergreen ground plant with dark leaves striped white along the midrib.", "One plant from above."),
 "cercis_canadensis": ("Small tree with heart-shaped leaves; pink flowers directly on the bare branches in early spring; flat bean pods.", "One heart-shaped leaf."),
 "quercus_nigra": ("Oak with small spoon-shaped leaves, widest near the tip, often held through winter; small acorns.", "A twig with several leaves."),
 "carpinus_caroliniana": ("Small tree with smooth, sinewy grey bark that looks like flexed muscle; oval toothed leaves.", "The bark and a leaf."),
 "lindera_benzoin": ("Shrub whose leaves and twigs smell spicy when crushed; tiny yellow flowers before the leaves; red berries.", "A twig with leaves."),
 "aesculus_pavia": ("Shrub with leaves of five leaflets spread like fingers; red tubular flower spikes in spring.", "One leaf from above."),
 "asplenium_platyneuron": ("Small upright fern with a shiny dark-brown stem and narrow fronds of alternating leaflets.", "One frond close up."),
 "kalmia_latifolia": ("Evergreen shrub with leathery leaves clustered at the twig ends and cup-shaped pink-white flowers in late spring.", "A twig with leaves."),
 "asimina_triloba": ("Understory tree with large drooping oval leaves, widest near the tip; maroon flowers; green banana-like fruit.", "One large leaf."),
 "passiflora_incarnata": ("Vine with three-lobed leaves and intricate purple fringed flowers; egg-shaped green fruit.", "A flower or one three-lobed leaf."),
 "juglans_nigra": ("Tall tree with long compound leaves of many leaflets; round green nuts that stain hands brown.", "One compound leaf."),
 "sassafras_albidum": ("Tree with three leaf shapes on one plant: oval, mitten, and three-lobed; twigs smell of root beer.", "A twig showing the different leaf shapes."),
 "pinus_taeda": ("Common pine with needles in bundles of three and prickly cones.", "A needle bundle."),
 "onoclea_sensibilis": ("Fern with broad, wavy-edged leaflets that look almost like a leaf, not a fern; separate bead-like fertile stalks.", "One frond flat on."),
 "hydrangea_quercifolia": ("Shrub with big oak-shaped lobed leaves and cone-shaped white flower clusters; peeling cinnamon bark.", "One leaf."),
 "ilex_vomitoria": ("Evergreen holly with small oval leaves with rounded teeth, no spines; red berries.", "A twig with leaves."),
 "juniperus_virginiana": ("Eastern red cedar: dense evergreen with scale-like foliage and blue berry-like cones; shredding reddish bark.", "A sprig of foliage."),
 "impatiens_capensis": ("Jewelweed: soft succulent stems, orange spotted flowers, seed pods that pop when touched. Grows along the creek.", "A flower and leaves."),
 "quercus_alba": ("White oak: leaves with rounded lobes, pale underneath; light grey flaky bark.", "One leaf flat on."),
 "arundinaria_gigantea": ("River cane: native bamboo in dense stands along creeks, with narrow leaves on woody jointed stems.", "A stem with leaves."),
 "phoradendron_leucarpum": ("Mistletoe: evergreen clumps growing on tree branches, oval leathery leaves and white berries.", "A clump on its branch."),
 "andersonglossum_virginianum": ("Wild comfrey: a rosette of large soft hairy leaves and a tall stalk of small pale-blue flowers in spring.", "The leaf rosette."),
 "eupatorium_capillifolium": ("Dogfennel: tall weedy plant with feathery, thread-like leaves that smell strong when crushed.", "A stem with the feathery leaves."),
 "solanum_carolinense": ("Horsenettle: prickly stems and leaves, star-shaped white or violet flowers, yellow tomato-like berries. Toxic.", "A leaf with its spines."),
 "ambrosia_artemisiifolia": ("Common ragweed: much-divided fern-like leaves and spikes of small green flowers.", "A leaf."),
 "tipularia_discolor": ("Crane-fly orchid: a single purple-backed leaf on the forest floor in winter, gone by summer when the flower stalk appears.", "The leaf showing its purple underside."),
 "cypripedium_acaule": ("Pink lady's slipper: two basal leaves and one pouch-shaped pink flower on a bare stalk in spring. Do not pick.", "The flower from the side."),
 "goodyera_pubescens": ("Downy rattlesnake plantain: a rosette of dark leaves netted with white veins.", "The rosette from above."),
 "pleopeltis_michauxiana": ("Resurrection fern: small fern growing on tree limbs, curled and brown when dry, green after rain.", "Fronds on their branch."),
 "athyrium_asplenioides": ("Southern lady fern: delicate, lacy, finely divided fronds in clumps, often with a reddish stem.", "One frond."),
 "woodwardia_areolata": ("Netted chain fern: broad lobed sterile fronds that look like a fern leaf cut from paper; separate narrow fertile fronds.", "One frond flat on."),
 "amauropelta_noveboracensis": ("New York fern: pale yellow-green fronds that taper at both ends, in large colonies.", "One frond."),
 "thalictrum_thalictroides": ("Rue anemone: small spring wildflower with white petal-like sepals and rounded three-lobed leaflets.", "A flower with leaves."),
 "trillium_cuneatum_note": ("", ""),
}
out = []
for c in classes:
    if c["tier"] != "native" or c["label"] in builtin: continue
    if known is not None and c["label"] not in known: continue
    notes = LOCAL_NOTES.get(c["label"], ("", ""))
    common = (c.get("common") or c["name"])
    common = common[0].upper() + common[1:]
    out.append({"label": c["label"], "scientificName": c["name"], "commonName": common, "tier": "native", "aggressiveness": 0.0,
                "documentedAtPreserve": False,
                "whyItMatters": "Native to the Georgia Piedmont and among the most-photographed plants within a few kilometres of the preserve on iNaturalist. Not a target: the scanner knows it so it is not mistaken for an invasive.",
                "howToRecognize": notes[0], "whatToPhotograph": notes[1], "lookAlike": None,
                "sourceURL": f"https://www.inaturalist.org/taxa/{c['taxon_id']}", "inatTaxonID": c["taxon_id"]})
(RES / "local_species.json").write_text(json.dumps(out, indent=1))
print("local_species.json:", len(out), "entries;", sum(1 for o in out if o["howToRecognize"]), "with field notes")
