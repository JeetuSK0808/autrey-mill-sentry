# Model card: InvasiveClassifier v4

Evaluated 2026-10-20. Every number here comes from `model/eval/v4_eval.json`, produced by `model/evaluate.py` on a held-out test split.

Backbone: timm `efficientnet_b0` (ImageNet pretrained), input 256 px, 24 epochs, AdamW + one-cycle LR, label smoothing 0.1, class-balanced sampling, strong augmentation (random resized crops, flips, rotation, colour jitter, blur, erasing). Trained on Apple MPS.

## Data and split
- Source: iNaturalist research-grade observations, photos licensed CC0 / CC-BY / CC-BY-NC only, Georgia first, then the south-eastern US, then the US. Attribution in `data/attribution.csv` (not committed) and `docs/LICENSES.md`.
- Split by observer (and therefore by observation): train 48603 / val 7542 / test 5896 images from 8040 / 907 / 1028 observers. No observer appears in two splits.
- Classes: 188 (14 Tier 1, 84 Tier 2, 88 native look-alikes, other_plant, not_plant).

## Calibration
- Temperature scaling fitted on validation: T = 0.803. ECE on validation 0.0888 raw -> 0.0124 calibrated. ECE on test 0.0113.

## Headline results (test split)
| Group | Classes | Test images | Top-1 | Top-3 |
|---|---|---|---|---|
| All | 188 | 5896 | 82.8% | 91.5% |
| Tier 1 (tuned) | 14 | 772 | 85.8% | 93.8% |
| Tier 2 (broad coverage) | 84 | 1832 | 84.0% | 93.0% |
| Native look-alikes | 88 | 3024 | 85.3% | 92.8% |

## The confirmed-invasive call
- Target precision for `.confirmedInvasive`: 98.0%. Chosen on validation: global threshold 0.88, margin 0.30, 13 per-class thresholds.
- Validation: precision 98.4%, coverage 61.1% (1704 confirmed calls).
- **Test: precision 96.2%, coverage 68.4%** (549 confirmed calls). Coverage is the fraction of true Tier 1 photos the app confirms; the rest go to "needs expert review".
- Native or other plants wrongly confirmed as invasive on test: 0.3%.
- not_plant photos rejected (top-1 not_plant with p >= 0.5): 49.4%.

## Hardest confusions (test, true -> predicted, count)
- asimina_parviflora -> asimina_triloba (8)
- sonchus_oleraceus -> sonchus_asper (6)
- liriope_spicata -> liriope_muscari (6)
- carpinus_caroliniana -> fagus_grandifolia (6)
- paspalum_urvillei -> sorghum_halepense (5)
- not_plant -> juglans_nigra (5)
- liriope_muscari -> liriope_spicata (5)
- elaeagnus_umbellata -> elaeagnus_pungens (5)
- cirsium_vulgare -> carduus_nutans (5)
- wisteria_sinensis -> wisteria_frutescens (4)
- wisteria_frutescens -> wisteria_sinensis (4)
- phyllostachys_aurea -> arundinaria_gigantea (4)

## Per-class precision / recall (test)
| Class | Tier | Support | Precision | Recall |
|---|---|---|---|---|
| ligustrum_sinense | tier1 | 55 | 81.1% | 78.2% |
| mahonia_bealei | tier1 | 52 | 98.0% | 96.2% |
| lonicera_japonica | tier1 | 58 | 87.5% | 72.4% |
| wisteria_sinensis | tier1 | 64 | 87.7% | 89.1% |
| vinca_minor | tier1 | 60 | 94.6% | 88.3% |
| elaeagnus_umbellata | tier1 | 65 | 79.1% | 81.5% |
| elaeagnus_pungens | tier1 | 46 | 78.7% | 80.4% |
| rosa_multiflora | tier1 | 57 | 95.8% | 80.7% |
| hedera_helix | tier1 | 48 | 86.5% | 93.8% |
| albizia_julibrissin | tier1 | 63 | 93.8% | 95.2% |
| paulownia_tomentosa | tier1 | 35 | 82.4% | 80.0% |
| microstegium_vimineum | tier1 | 45 | 87.2% | 91.1% |
| pueraria_montana | tier1 | 60 | 93.1% | 90.0% |
| nandina_domestica | tier1 | 64 | 86.9% | 82.8% |
| lonicera_sempervirens | native | 31 | 93.5% | 93.5% |
| wisteria_frutescens | native | 22 | 56.0% | 63.6% |
| viburnum_acerifolium | native | 23 | 80.0% | 87.0% |
| viburnum_dentatum | native | 23 | 66.7% | 87.0% |
| ilex_opaca | native | 34 | 82.1% | 94.1% |
| toxicodendron_radicans | native | 38 | 76.1% | 92.1% |
| parthenocissus_quinquefolia | native | 35 | 82.4% | 80.0% |
| vitis_rotundifolia | native | 40 | 92.3% | 90.0% |
| rosa_carolina | native | 34 | 78.0% | 94.1% |
| rubus_argutus | native | 40 | 91.2% | 77.5% |
| mitchella_repens | native | 34 | 87.2% | 100.0% |
| catalpa_bignonioides | native | 50 | 91.1% | 82.0% |
| chasmanthium_latifolium | native | 25 | 85.2% | 92.0% |
| smilax_rotundifolia | native | 42 | 84.4% | 90.5% |
| ailanthus_altissima | tier2 | 22 | 78.3% | 81.8% |
| alternanthera_philoxeroides | tier2 | 13 | 85.7% | 92.3% |
| dryopteris_erythrosora | tier2 | 10 | 90.0% | 90.0% |
| eichhornia_crassipes | tier2 | 20 | 90.5% | 95.0% |
| lespedeza_bicolor | tier2 | 20 | 90.0% | 90.0% |
| lespedeza_cuneata | tier2 | 27 | 88.9% | 88.9% |
| lygodium_japonicum | tier2 | 27 | 82.1% | 85.2% |
| melia_azedarach | tier2 | 29 | 80.0% | 82.8% |
| murdannia_keisak | tier2 | 14 | 86.7% | 92.9% |
| triadica_sebifera | tier2 | 24 | 100.0% | 75.0% |
| ardisia_crenata | tier2 | 31 | 96.4% | 87.1% |
| crotalaria_spectabilis | tier2 | 17 | 81.0% | 100.0% |
| dioscorea_polystachya | tier2 | 19 | 90.0% | 94.7% |
| leucanthemum_vulgare | tier2 | 31 | 93.1% | 87.1% |
| ligustrum_lucidum | tier2 | 28 | 74.1% | 71.4% |
| lonicera_maackii | tier2 | 26 | 76.0% | 73.1% |
| miscanthus_sinensis | tier2 | 27 | 88.5% | 85.2% |
| myriophyllum_aquaticum | tier2 | 21 | 87.0% | 95.2% |
| nasturtium_officinale | tier2 | 18 | 88.2% | 83.3% |
| phyllostachys_aurea | tier2 | 28 | 95.5% | 75.0% |
| sesbania_punicea | tier2 | 19 | 89.5% | 89.5% |
| spiraea_japonica | tier2 | 24 | 88.5% | 95.8% |
| vinca_major | tier2 | 16 | 84.2% | 100.0% |
| vitex_rotundifolia | tier2 | 13 | 80.0% | 92.3% |
| ajuga_reptans | tier2 | 29 | 93.5% | 100.0% |
| ampelopsis_glandulosa | tier2 | 21 | 76.0% | 90.5% |
| anthoxanthum_odoratum | tier2 | 21 | 60.0% | 57.1% |
| arundo_donax | tier2 | 20 | 87.0% | 100.0% |
| berberis_thunbergii | tier2 | 19 | 85.7% | 94.7% |
| broussonetia_papyrifera | tier2 | 17 | 66.7% | 82.4% |
| carduus_nutans | tier2 | 35 | 87.2% | 97.1% |
| centaurea_cyanus | tier2 | 25 | 92.0% | 92.0% |
| citrus_trifoliata | tier2 | 13 | 76.5% | 100.0% |
| clematis_terniflora | tier2 | 26 | 90.5% | 73.1% |
| colocasia_esculenta | tier2 | 7 | 100.0% | 85.7% |
| daucus_carota | tier2 | 20 | 94.7% | 90.0% |
| euonymus_fortunei | tier2 | 33 | 88.5% | 69.7% |
| hemerocallis_fulva | tier2 | 23 | 95.7% | 95.7% |
| hibiscus_syriacus | tier2 | 27 | 96.3% | 96.3% |
| ligustrum_japonicum | tier2 | 25 | 73.1% | 76.0% |
| liriope_muscari | tier2 | 22 | 65.4% | 77.3% |
| lonicera_fragrantissima | tier2 | 25 | 73.3% | 88.0% |
| morus_alba | tier2 | 29 | 85.7% | 62.1% |
| paspalum_urvillei | tier2 | 35 | 92.3% | 68.6% |
| perilla_frutescens | tier2 | 22 | 81.5% | 100.0% |
| phragmites_australis | tier2 | 18 | 64.7% | 61.1% |
| pyrus_calleryana | tier2 | 20 | 60.9% | 70.0% |
| rubus_armeniacus | tier2 | 24 | 87.0% | 83.3% |
| securigera_varia | tier2 | 22 | 84.6% | 100.0% |
| solanum_viarum | tier2 | 27 | 95.5% | 77.8% |
| sorghum_halepense | tier2 | 21 | 60.9% | 66.7% |
| vernicia_fordii | tier2 | 23 | 71.4% | 65.2% |
| akebia_quinata | tier2 | 37 | 90.9% | 81.1% |
| allium_vineale | tier2 | 11 | 88.9% | 72.7% |
| artemisia_vulgaris | tier2 | 12 | 81.8% | 75.0% |
| cirsium_vulgare | tier2 | 31 | 88.9% | 77.4% |
| euonymus_alatus | tier2 | 23 | 62.1% | 78.3% |
| fatoua_villosa | tier2 | 11 | 58.8% | 90.9% |
| firmiana_simplex | tier2 | 22 | 76.9% | 90.9% |
| ilex_cornuta | tier2 | 20 | 78.3% | 90.0% |
| ilex_crenata | tier2 | 34 | 65.6% | 61.8% |
| ipomoea_coccinea | tier2 | 14 | 77.8% | 100.0% |
| ipomoea_purpurea | tier2 | 10 | 71.4% | 100.0% |
| jacquemontia_tamnifolia | tier2 | 34 | 96.6% | 82.4% |
| kummerowia_stipulacea | tier2 | 16 | 92.9% | 81.2% |
| kummerowia_striata | tier2 | 16 | 88.9% | 100.0% |
| liriope_spicata | tier2 | 27 | 62.5% | 74.1% |
| persicaria_longiseta | tier2 | 21 | 76.0% | 90.5% |
| quercus_acutissima | tier2 | 15 | 59.1% | 86.7% |
| rosa_laevigata | tier2 | 24 | 88.5% | 95.8% |
| rubus_phoenicolasius | tier2 | 23 | 88.5% | 100.0% |
| setaria_pumila | tier2 | 20 | 88.9% | 80.0% |
| sonchus_asper | tier2 | 15 | 63.2% | 80.0% |
| sonchus_oleraceus | tier2 | 18 | 88.9% | 44.4% |
| torilis_arvensis | tier2 | 26 | 75.0% | 92.3% |
| verbascum_thapsus | tier2 | 22 | 100.0% | 95.5% |
| verbena_bonariensis | tier2 | 24 | 95.2% | 83.3% |
| buddleja_davidii | tier2 | 20 | 77.3% | 85.0% |
| alliaria_petiolata | tier2 | 21 | 100.0% | 95.2% |
| achyranthes_japonica | tier2 | 16 | 88.2% | 93.8% |
| arthraxon_hispidus | tier2 | 21 | 80.0% | 95.2% |
| celastrus_orbiculatus | tier2 | 28 | 69.0% | 71.4% |
| imperata_cylindrica | tier2 | 6 | 25.0% | 66.7% |
| reynoutria_japonica | tier2 | 21 | 85.0% | 81.0% |
| liquidambar_styraciflua | native | 48 | 86.5% | 66.7% |
| polystichum_acrostichoides | native | 27 | 81.2% | 96.3% |
| podophyllum_peltatum | native | 31 | 96.7% | 93.5% |
| magnolia_grandiflora | native | 26 | 81.0% | 65.4% |
| phoradendron_leucarpum | native | 17 | 78.9% | 88.2% |
| liriodendron_tulipifera | native | 43 | 69.6% | 74.4% |
| trillium_cuneatum | native | 30 | 93.1% | 90.0% |
| andersonglossum_virginianum | native | 25 | 88.9% | 96.0% |
| phytolacca_americana | native | 29 | 80.0% | 82.8% |
| fagus_grandifolia | native | 27 | 55.0% | 81.5% |
| packera_glabella | native | 53 | 94.1% | 90.6% |
| verbesina_occidentalis | native | 53 | 83.6% | 86.8% |
| asimina_parviflora | native | 32 | 67.7% | 65.6% |
| cornus_florida | native | 27 | 59.3% | 59.3% |
| bignonia_capreolata | native | 30 | 71.0% | 73.3% |
| solanum_carolinense | native | 44 | 88.4% | 86.4% |
| campsis_radicans | native | 50 | 95.7% | 88.0% |
| diospyros_virginiana | native | 42 | 71.1% | 76.2% |
| tipularia_discolor | native | 31 | 85.7% | 96.8% |
| acer_rubrum | native | 36 | 78.3% | 50.0% |
| eupatorium_serotinum | native | 45 | 88.9% | 88.9% |
| prunus_serotina | native | 38 | 82.9% | 76.3% |
| euonymus_americanus | native | 22 | 79.2% | 86.4% |
| thalictrum_thalictroides | native | 27 | 93.1% | 100.0% |
| erechtites_hieraciifolius | native | 25 | 74.2% | 92.0% |
| eupatorium_capillifolium | native | 22 | 75.9% | 100.0% |
| athyrium_asplenioides | native | 32 | 81.8% | 84.4% |
| cypripedium_acaule | native | 39 | 86.4% | 97.4% |
| acer_negundo | native | 46 | 92.9% | 84.8% |
| callicarpa_americana | native | 41 | 90.5% | 92.7% |
| chimaphila_maculata | native | 27 | 96.4% | 100.0% |
| woodwardia_areolata | native | 28 | 96.6% | 100.0% |
| cercis_canadensis | native | 33 | 78.9% | 90.9% |
| quercus_nigra | native | 32 | 67.6% | 71.9% |
| carpinus_caroliniana | native | 52 | 75.6% | 65.4% |
| lindera_benzoin | native | 39 | 68.1% | 82.1% |
| erigeron_philadelphicus | native | 31 | 89.7% | 83.9% |
| aesculus_pavia | native | 36 | 97.1% | 91.7% |
| asplenium_platyneuron | native | 42 | 92.7% | 90.5% |
| diodia_virginiana | native | 43 | 93.0% | 93.0% |
| elephantopus_tomentosus | native | 27 | 92.9% | 96.3% |
| amauropelta_noveboracensis | native | 34 | 86.5% | 94.1% |
| asarum_arifolium | native | 41 | 95.0% | 92.7% |
| kalmia_latifolia | native | 34 | 86.1% | 91.2% |
| asimina_triloba | native | 28 | 65.7% | 82.1% |
| passiflora_incarnata | native | 54 | 95.3% | 75.9% |
| magnolia_tripetala | native | 40 | 89.5% | 85.0% |
| ambrosia_artemisiifolia | native | 31 | 88.2% | 96.8% |
| juglans_nigra | native | 15 | 41.4% | 80.0% |
| sassafras_albidum | native | 42 | 89.7% | 83.3% |
| pinus_taeda | native | 45 | 84.4% | 84.4% |
| goodyera_pubescens | native | 19 | 100.0% | 100.0% |
| packera_anonyma | native | 39 | 88.6% | 79.5% |
| oxalis_violacea | native | 34 | 96.9% | 91.2% |
| onoclea_sensibilis | native | 38 | 94.6% | 92.1% |
| hydrangea_quercifolia | native | 34 | 84.6% | 97.1% |
| verbesina_alternifolia | native | 17 | 65.2% | 88.2% |
| ilex_vomitoria | native | 31 | 66.7% | 77.4% |
| houstonia_pusilla | native | 28 | 80.0% | 100.0% |
| melothria_pendula | native | 31 | 84.4% | 87.1% |
| persicaria_virginiana | native | 39 | 88.9% | 82.1% |
| arnoglossum_atriplicifolium | native | 17 | 73.7% | 82.4% |
| pleopeltis_michauxiana | native | 28 | 86.2% | 89.3% |
| acer_floridanum | native | 46 | 89.1% | 89.1% |
| quercus_rubra | native | 42 | 81.6% | 73.8% |
| quercus_falcata | native | 25 | 54.8% | 68.0% |
| sambucus_canadensis | native | 30 | 89.3% | 83.3% |
| gelsemium_sempervirens | native | 40 | 91.4% | 80.0% |
| vaccinium_arboreum | native | 36 | 84.2% | 88.9% |
| juniperus_virginiana | native | 37 | 75.0% | 81.1% |
| impatiens_capensis | native | 31 | 96.7% | 93.5% |
| quercus_alba | native | 30 | 63.9% | 76.7% |
| arundinaria_gigantea | native | 49 | 87.0% | 95.9% |
| vitis_aestivalis | native | 40 | 88.2% | 75.0% |
| other_plant | other | 183 | 51.6% | 26.8% |
| not_plant | other | 85 | 80.3% | 62.4% |

## Honest limits
- These are iNaturalist photos: many are clean, well-lit close-ups by people who already knew the plant. Field accuracy on a phone in the preserve will be lower. Field Test mode exists to measure that gap; no field number is claimed until it is measured.
- Tier 2 accuracy is lower by design (fewer images per class). Tier 2 results are never shown as confirmed.
- The model does not know rare or protected natives; they come out as other_plant.
- AI suggestion, not a guarantee. Staff make the final call.
