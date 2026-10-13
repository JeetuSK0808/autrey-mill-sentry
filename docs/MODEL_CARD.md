# Model card: InvasiveClassifier v2

Evaluated 2026-10-12. Every number here comes from `model/eval/v2_eval.json`, produced by `model/evaluate.py` on a held-out test split.

Backbone: timm `efficientnet_b0` (ImageNet pretrained), input 256 px, 20 epochs, AdamW + one-cycle LR, label smoothing 0.1, class-balanced sampling, strong augmentation (random resized crops, flips, rotation, colour jitter, blur, erasing). Trained on Apple MPS.

## Data and split
- Source: iNaturalist research-grade observations, photos licensed CC0 / CC-BY / CC-BY-NC only, Georgia first, then the south-eastern US, then the US. Attribution in `data/attribution.csv` (not committed) and `docs/LICENSES.md`.
- Split by observer (and therefore by observation): train 26199 / val 4131 / test 3234 images from 6430 / 702 / 827 observers. No observer appears in two splits.
- Classes: 114 (14 Tier 1, 84 Tier 2, 14 native look-alikes, other_plant, not_plant).

## Calibration
- Temperature scaling fitted on validation: T = 0.796. ECE on validation 0.0940 raw -> 0.0244 calibrated. ECE on test 0.0159.

## Headline results (test split)
| Group | Classes | Test images | Top-1 | Top-3 |
|---|---|---|---|---|
| All | 114 | 3234 | 85.6% | 93.4% |
| Tier 1 (tuned) | 14 | 772 | 88.7% | 95.7% |
| Tier 2 (broad coverage) | 84 | 1832 | 85.5% | 93.0% |
| Native look-alikes | 14 | 466 | 90.3% | 94.8% |

## The confirmed-invasive call
- Target precision for `.confirmedInvasive`: 97.0%. Chosen on validation: global threshold 0.82, margin 0.30, 14 per-class thresholds.
- Validation: precision 98.1%, coverage 74.4% (1040 confirmed calls).
- **Test: precision 95.9%, coverage 78.8%** (634 confirmed calls). Coverage is the fraction of true Tier 1 photos the app confirms; the rest go to "needs expert review".
- Native or other plants wrongly confirmed as invasive on test: 0.8%.
- not_plant photos rejected (top-1 not_plant with p >= 0.5): 74.2%.

## Hardest confusions (test, true -> predicted, count)
- sonchus_oleraceus -> sonchus_asper (7)
- elaeagnus_umbellata -> elaeagnus_pungens (6)
- wisteria_sinensis -> wisteria_frutescens (5)
- liriope_muscari -> liriope_spicata (5)
- rosa_multiflora -> rosa_carolina (4)
- other_plant -> viburnum_dentatum (4)
- other_plant -> toxicodendron_radicans (4)
- not_plant -> other_plant (4)
- liriope_spicata -> liriope_muscari (4)
- ligustrum_lucidum -> ligustrum_japonicum (4)
- cirsium_vulgare -> carduus_nutans (4)
- wisteria_frutescens -> wisteria_sinensis (3)

## Per-class precision / recall (test)
| Class | Tier | Support | Precision | Recall |
|---|---|---|---|---|
| ligustrum_sinense | tier1 | 55 | 77.4% | 87.3% |
| mahonia_bealei | tier1 | 52 | 92.7% | 98.1% |
| lonicera_japonica | tier1 | 58 | 84.6% | 75.9% |
| wisteria_sinensis | tier1 | 64 | 79.2% | 89.1% |
| vinca_minor | tier1 | 60 | 94.8% | 91.7% |
| elaeagnus_umbellata | tier1 | 65 | 87.1% | 83.1% |
| elaeagnus_pungens | tier1 | 46 | 80.9% | 82.6% |
| rosa_multiflora | tier1 | 57 | 95.7% | 78.9% |
| hedera_helix | tier1 | 48 | 93.9% | 95.8% |
| albizia_julibrissin | tier1 | 63 | 91.0% | 96.8% |
| paulownia_tomentosa | tier1 | 35 | 67.4% | 82.9% |
| microstegium_vimineum | tier1 | 45 | 95.7% | 97.8% |
| pueraria_montana | tier1 | 60 | 94.9% | 93.3% |
| nandina_domestica | tier1 | 64 | 93.4% | 89.1% |
| lonicera_sempervirens | native | 31 | 90.3% | 90.3% |
| wisteria_frutescens | native | 22 | 63.0% | 77.3% |
| viburnum_acerifolium | native | 23 | 95.2% | 87.0% |
| viburnum_dentatum | native | 23 | 71.4% | 87.0% |
| ilex_opaca | native | 34 | 79.1% | 100.0% |
| toxicodendron_radicans | native | 38 | 85.7% | 94.7% |
| parthenocissus_quinquefolia | native | 35 | 93.3% | 80.0% |
| vitis_rotundifolia | native | 40 | 95.0% | 95.0% |
| rosa_carolina | native | 34 | 79.5% | 91.2% |
| rubus_argutus | native | 35 | 86.8% | 94.3% |
| mitchella_repens | native | 34 | 94.4% | 100.0% |
| catalpa_bignonioides | native | 50 | 89.1% | 82.0% |
| chasmanthium_latifolium | native | 25 | 88.5% | 92.0% |
| smilax_rotundifolia | native | 42 | 84.4% | 90.5% |
| ailanthus_altissima | tier2 | 22 | 81.8% | 81.8% |
| alternanthera_philoxeroides | tier2 | 13 | 76.5% | 100.0% |
| dryopteris_erythrosora | tier2 | 10 | 90.9% | 100.0% |
| eichhornia_crassipes | tier2 | 20 | 95.0% | 95.0% |
| lespedeza_bicolor | tier2 | 20 | 90.0% | 90.0% |
| lespedeza_cuneata | tier2 | 27 | 87.5% | 77.8% |
| lygodium_japonicum | tier2 | 27 | 88.0% | 81.5% |
| melia_azedarach | tier2 | 29 | 92.6% | 86.2% |
| murdannia_keisak | tier2 | 14 | 85.7% | 85.7% |
| triadica_sebifera | tier2 | 24 | 66.7% | 66.7% |
| ardisia_crenata | tier2 | 31 | 93.3% | 90.3% |
| crotalaria_spectabilis | tier2 | 17 | 84.2% | 94.1% |
| dioscorea_polystachya | tier2 | 19 | 72.0% | 94.7% |
| leucanthemum_vulgare | tier2 | 31 | 96.4% | 87.1% |
| ligustrum_lucidum | tier2 | 28 | 67.7% | 75.0% |
| lonicera_maackii | tier2 | 26 | 84.2% | 61.5% |
| miscanthus_sinensis | tier2 | 27 | 76.5% | 96.3% |
| myriophyllum_aquaticum | tier2 | 21 | 95.2% | 95.2% |
| nasturtium_officinale | tier2 | 18 | 94.4% | 94.4% |
| phyllostachys_aurea | tier2 | 28 | 81.2% | 92.9% |
| sesbania_punicea | tier2 | 19 | 90.5% | 100.0% |
| spiraea_japonica | tier2 | 24 | 88.0% | 91.7% |
| vinca_major | tier2 | 16 | 94.1% | 100.0% |
| vitex_rotundifolia | tier2 | 13 | 81.2% | 100.0% |
| ajuga_reptans | tier2 | 29 | 96.4% | 93.1% |
| ampelopsis_glandulosa | tier2 | 21 | 87.5% | 100.0% |
| anthoxanthum_odoratum | tier2 | 21 | 88.9% | 76.2% |
| arundo_donax | tier2 | 20 | 81.0% | 85.0% |
| berberis_thunbergii | tier2 | 19 | 90.0% | 94.7% |
| broussonetia_papyrifera | tier2 | 17 | 82.4% | 82.4% |
| carduus_nutans | tier2 | 35 | 89.5% | 97.1% |
| centaurea_cyanus | tier2 | 25 | 100.0% | 88.0% |
| citrus_trifoliata | tier2 | 13 | 76.5% | 100.0% |
| clematis_terniflora | tier2 | 26 | 90.5% | 73.1% |
| colocasia_esculenta | tier2 | 7 | 85.7% | 85.7% |
| daucus_carota | tier2 | 20 | 88.2% | 75.0% |
| euonymus_fortunei | tier2 | 33 | 96.3% | 78.8% |
| hemerocallis_fulva | tier2 | 23 | 100.0% | 95.7% |
| hibiscus_syriacus | tier2 | 27 | 85.7% | 88.9% |
| ligustrum_japonicum | tier2 | 25 | 71.4% | 80.0% |
| liriope_muscari | tier2 | 22 | 73.9% | 77.3% |
| lonicera_fragrantissima | tier2 | 25 | 74.1% | 80.0% |
| morus_alba | tier2 | 29 | 83.3% | 69.0% |
| paspalum_urvillei | tier2 | 35 | 93.1% | 77.1% |
| perilla_frutescens | tier2 | 22 | 100.0% | 95.5% |
| phragmites_australis | tier2 | 18 | 87.5% | 77.8% |
| pyrus_calleryana | tier2 | 20 | 93.3% | 70.0% |
| rubus_armeniacus | tier2 | 24 | 95.2% | 83.3% |
| securigera_varia | tier2 | 22 | 95.2% | 90.9% |
| solanum_viarum | tier2 | 27 | 92.3% | 88.9% |
| sorghum_halepense | tier2 | 21 | 75.0% | 57.1% |
| vernicia_fordii | tier2 | 23 | 88.9% | 69.6% |
| akebia_quinata | tier2 | 37 | 88.2% | 81.1% |
| allium_vineale | tier2 | 11 | 75.0% | 81.8% |
| artemisia_vulgaris | tier2 | 12 | 90.0% | 75.0% |
| cirsium_vulgare | tier2 | 31 | 86.2% | 80.6% |
| euonymus_alatus | tier2 | 23 | 87.5% | 91.3% |
| fatoua_villosa | tier2 | 11 | 71.4% | 90.9% |
| firmiana_simplex | tier2 | 22 | 80.0% | 90.9% |
| ilex_cornuta | tier2 | 20 | 85.7% | 90.0% |
| ilex_crenata | tier2 | 34 | 77.8% | 61.8% |
| ipomoea_coccinea | tier2 | 14 | 93.3% | 100.0% |
| ipomoea_purpurea | tier2 | 10 | 81.8% | 90.0% |
| jacquemontia_tamnifolia | tier2 | 34 | 100.0% | 85.3% |
| kummerowia_stipulacea | tier2 | 16 | 88.2% | 93.8% |
| kummerowia_striata | tier2 | 16 | 100.0% | 100.0% |
| liriope_spicata | tier2 | 27 | 74.1% | 74.1% |
| persicaria_longiseta | tier2 | 21 | 94.7% | 85.7% |
| quercus_acutissima | tier2 | 15 | 65.2% | 100.0% |
| rosa_laevigata | tier2 | 24 | 92.0% | 95.8% |
| rubus_phoenicolasius | tier2 | 23 | 100.0% | 100.0% |
| setaria_pumila | tier2 | 20 | 94.1% | 80.0% |
| sonchus_asper | tier2 | 15 | 66.7% | 93.3% |
| sonchus_oleraceus | tier2 | 18 | 100.0% | 55.6% |
| torilis_arvensis | tier2 | 26 | 76.7% | 88.5% |
| verbascum_thapsus | tier2 | 22 | 100.0% | 90.9% |
| verbena_bonariensis | tier2 | 24 | 90.9% | 83.3% |
| buddleja_davidii | tier2 | 20 | 86.4% | 95.0% |
| alliaria_petiolata | tier2 | 21 | 100.0% | 95.2% |
| achyranthes_japonica | tier2 | 16 | 88.2% | 93.8% |
| arthraxon_hispidus | tier2 | 21 | 85.7% | 85.7% |
| celastrus_orbiculatus | tier2 | 28 | 77.4% | 85.7% |
| imperata_cylindrica | tier2 | 6 | 41.7% | 83.3% |
| reynoutria_japonica | tier2 | 21 | 83.3% | 95.2% |
| other_plant | other | 98 | 59.0% | 46.9% |
| not_plant | other | 66 | 78.1% | 75.8% |

## Honest limits
- These are iNaturalist photos: many are clean, well-lit close-ups by people who already knew the plant. Field accuracy on a phone in the preserve will be lower. Field Test mode exists to measure that gap; no field number is claimed until it is measured.
- Tier 2 accuracy is lower by design (fewer images per class). Tier 2 results are never shown as confirmed.
- The model does not know rare or protected natives; they come out as other_plant.
- AI suggestion, not a guarantee. Staff make the final call.
