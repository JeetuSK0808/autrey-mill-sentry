# Model card: InvasiveClassifier v1

Evaluated 2026-10-12. Every number here comes from `model/eval/v1_eval.json`, produced by `model/evaluate.py` on a held-out test split.

## Data and split
- Source: iNaturalist research-grade observations, photos licensed CC0 / CC-BY / CC-BY-NC only, Georgia first, then the south-eastern US, then the US. Attribution in `data/attribution.csv` (not committed) and `docs/LICENSES.md`.
- Split by observer (and therefore by observation): train 26199 / val 4131 / test 3234 images from 6430 / 702 / 827 observers. No observer appears in two splits.
- Classes: 114 (14 Tier 1, 84 Tier 2, 14 native look-alikes, other_plant, not_plant).

## Calibration
- Temperature scaling fitted on validation: T = 0.779. ECE on validation 0.1141 raw -> 0.0189 calibrated. ECE on test 0.0122.

## Headline results (test split)
| Group | Classes | Test images | Top-1 | Top-3 |
|---|---|---|---|---|
| All | 114 | 3234 | 81.2% | 90.8% |
| Tier 1 (tuned) | 14 | 772 | 86.7% | 93.0% |
| Tier 2 (broad coverage) | 84 | 1832 | 80.3% | 90.9% |
| Native look-alikes | 14 | 466 | 85.6% | 94.2% |

## The confirmed-invasive call
- Target precision for `.confirmedInvasive`: 95.0%. Chosen on validation: global threshold 0.76, margin 0.30, 14 per-class thresholds.
- Validation: precision 95.7%, coverage 68.6% (983 confirmed calls).
- **Test: precision 96.4%, coverage 72.3%** (579 confirmed calls). Coverage is the fraction of true Tier 1 photos the app confirms; the rest go to "needs expert review".
- Native or other plants wrongly confirmed as invasive on test: 0.3%.
- not_plant photos rejected (top-1 not_plant with p >= 0.5): 75.8%.

## Hardest confusions (test, true -> predicted, count)
- liriope_spicata -> liriope_muscari (7)
- wisteria_sinensis -> wisteria_frutescens (6)
- sonchus_oleraceus -> sonchus_asper (6)
- other_plant -> toxicodendron_radicans (6)
- ligustrum_lucidum -> ligustrum_japonicum (6)
- elaeagnus_umbellata -> elaeagnus_pungens (6)
- other_plant -> dryopteris_erythrosora (4)
- other_plant -> celastrus_orbiculatus (4)
- catalpa_bignonioides -> paulownia_tomentosa (4)
- vinca_minor -> mitchella_repens (3)
- phragmites_australis -> miscanthus_sinensis (3)
- paspalum_urvillei -> sorghum_halepense (3)

## Per-class precision / recall (test)
| Class | Tier | Support | Precision | Recall |
|---|---|---|---|---|
| ligustrum_sinense | tier1 | 55 | 80.7% | 83.6% |
| mahonia_bealei | tier1 | 52 | 91.1% | 98.1% |
| lonicera_japonica | tier1 | 58 | 84.6% | 75.9% |
| wisteria_sinensis | tier1 | 64 | 85.0% | 79.7% |
| vinca_minor | tier1 | 60 | 89.8% | 88.3% |
| elaeagnus_umbellata | tier1 | 65 | 84.4% | 83.1% |
| elaeagnus_pungens | tier1 | 46 | 68.4% | 84.8% |
| rosa_multiflora | tier1 | 57 | 87.3% | 84.2% |
| hedera_helix | tier1 | 48 | 91.5% | 89.6% |
| albizia_julibrissin | tier1 | 63 | 85.9% | 96.8% |
| paulownia_tomentosa | tier1 | 35 | 69.2% | 77.1% |
| microstegium_vimineum | tier1 | 45 | 91.3% | 93.3% |
| pueraria_montana | tier1 | 60 | 93.3% | 93.3% |
| nandina_domestica | tier1 | 64 | 93.1% | 84.4% |
| lonicera_sempervirens | native | 31 | 81.2% | 83.9% |
| wisteria_frutescens | native | 22 | 58.6% | 77.3% |
| viburnum_acerifolium | native | 23 | 72.4% | 91.3% |
| viburnum_dentatum | native | 23 | 70.4% | 82.6% |
| ilex_opaca | native | 34 | 81.6% | 91.2% |
| toxicodendron_radicans | native | 38 | 78.0% | 84.2% |
| parthenocissus_quinquefolia | native | 35 | 73.0% | 77.1% |
| vitis_rotundifolia | native | 40 | 85.4% | 87.5% |
| rosa_carolina | native | 34 | 87.5% | 82.4% |
| rubus_argutus | native | 35 | 81.1% | 85.7% |
| mitchella_repens | native | 34 | 82.9% | 100.0% |
| catalpa_bignonioides | native | 50 | 88.4% | 76.0% |
| chasmanthium_latifolium | native | 25 | 79.3% | 92.0% |
| smilax_rotundifolia | native | 42 | 80.9% | 90.5% |
| ailanthus_altissima | tier2 | 22 | 63.0% | 77.3% |
| alternanthera_philoxeroides | tier2 | 13 | 76.5% | 100.0% |
| dryopteris_erythrosora | tier2 | 10 | 71.4% | 100.0% |
| eichhornia_crassipes | tier2 | 20 | 81.0% | 85.0% |
| lespedeza_bicolor | tier2 | 20 | 73.9% | 85.0% |
| lespedeza_cuneata | tier2 | 27 | 95.5% | 77.8% |
| lygodium_japonicum | tier2 | 27 | 95.5% | 77.8% |
| melia_azedarach | tier2 | 29 | 81.5% | 75.9% |
| murdannia_keisak | tier2 | 14 | 80.0% | 85.7% |
| triadica_sebifera | tier2 | 24 | 75.0% | 62.5% |
| ardisia_crenata | tier2 | 31 | 92.9% | 83.9% |
| crotalaria_spectabilis | tier2 | 17 | 100.0% | 100.0% |
| dioscorea_polystachya | tier2 | 19 | 81.0% | 89.5% |
| leucanthemum_vulgare | tier2 | 31 | 92.6% | 80.6% |
| ligustrum_lucidum | tier2 | 28 | 68.2% | 53.6% |
| lonicera_maackii | tier2 | 26 | 72.0% | 69.2% |
| miscanthus_sinensis | tier2 | 27 | 80.6% | 92.6% |
| myriophyllum_aquaticum | tier2 | 21 | 95.0% | 90.5% |
| nasturtium_officinale | tier2 | 18 | 77.3% | 94.4% |
| phyllostachys_aurea | tier2 | 28 | 76.9% | 71.4% |
| sesbania_punicea | tier2 | 19 | 88.9% | 84.2% |
| spiraea_japonica | tier2 | 24 | 81.5% | 91.7% |
| vinca_major | tier2 | 16 | 87.5% | 87.5% |
| vitex_rotundifolia | tier2 | 13 | 75.0% | 92.3% |
| ajuga_reptans | tier2 | 29 | 90.3% | 96.6% |
| ampelopsis_glandulosa | tier2 | 21 | 75.0% | 85.7% |
| anthoxanthum_odoratum | tier2 | 21 | 69.2% | 42.9% |
| arundo_donax | tier2 | 20 | 85.7% | 90.0% |
| berberis_thunbergii | tier2 | 19 | 70.6% | 63.2% |
| broussonetia_papyrifera | tier2 | 17 | 57.1% | 94.1% |
| carduus_nutans | tier2 | 35 | 88.6% | 88.6% |
| centaurea_cyanus | tier2 | 25 | 91.7% | 88.0% |
| citrus_trifoliata | tier2 | 13 | 70.6% | 92.3% |
| clematis_terniflora | tier2 | 26 | 84.2% | 61.5% |
| colocasia_esculenta | tier2 | 7 | 75.0% | 85.7% |
| daucus_carota | tier2 | 20 | 70.0% | 70.0% |
| euonymus_fortunei | tier2 | 33 | 95.8% | 69.7% |
| hemerocallis_fulva | tier2 | 23 | 100.0% | 95.7% |
| hibiscus_syriacus | tier2 | 27 | 92.6% | 92.6% |
| ligustrum_japonicum | tier2 | 25 | 59.4% | 76.0% |
| liriope_muscari | tier2 | 22 | 65.5% | 86.4% |
| lonicera_fragrantissima | tier2 | 25 | 83.3% | 80.0% |
| morus_alba | tier2 | 29 | 94.1% | 55.2% |
| paspalum_urvillei | tier2 | 35 | 89.7% | 74.3% |
| perilla_frutescens | tier2 | 22 | 82.6% | 86.4% |
| phragmites_australis | tier2 | 18 | 80.0% | 66.7% |
| pyrus_calleryana | tier2 | 20 | 75.0% | 75.0% |
| rubus_armeniacus | tier2 | 24 | 90.9% | 83.3% |
| securigera_varia | tier2 | 22 | 91.3% | 95.5% |
| solanum_viarum | tier2 | 27 | 92.0% | 85.2% |
| sorghum_halepense | tier2 | 21 | 63.6% | 66.7% |
| vernicia_fordii | tier2 | 23 | 88.2% | 65.2% |
| akebia_quinata | tier2 | 37 | 93.3% | 75.7% |
| allium_vineale | tier2 | 11 | 75.0% | 81.8% |
| artemisia_vulgaris | tier2 | 12 | 81.8% | 75.0% |
| cirsium_vulgare | tier2 | 31 | 89.7% | 83.9% |
| euonymus_alatus | tier2 | 23 | 78.3% | 78.3% |
| fatoua_villosa | tier2 | 11 | 69.2% | 81.8% |
| firmiana_simplex | tier2 | 22 | 67.9% | 86.4% |
| ilex_cornuta | tier2 | 20 | 81.0% | 85.0% |
| ilex_crenata | tier2 | 34 | 69.0% | 58.8% |
| ipomoea_coccinea | tier2 | 14 | 86.7% | 92.9% |
| ipomoea_purpurea | tier2 | 10 | 90.9% | 100.0% |
| jacquemontia_tamnifolia | tier2 | 34 | 96.9% | 91.2% |
| kummerowia_stipulacea | tier2 | 16 | 87.5% | 87.5% |
| kummerowia_striata | tier2 | 16 | 94.1% | 100.0% |
| liriope_spicata | tier2 | 27 | 75.0% | 66.7% |
| persicaria_longiseta | tier2 | 21 | 93.8% | 71.4% |
| quercus_acutissima | tier2 | 15 | 54.2% | 86.7% |
| rosa_laevigata | tier2 | 24 | 90.9% | 83.3% |
| rubus_phoenicolasius | tier2 | 23 | 87.5% | 91.3% |
| setaria_pumila | tier2 | 20 | 80.0% | 80.0% |
| sonchus_asper | tier2 | 15 | 68.4% | 86.7% |
| sonchus_oleraceus | tier2 | 18 | 83.3% | 55.6% |
| torilis_arvensis | tier2 | 26 | 73.3% | 84.6% |
| verbascum_thapsus | tier2 | 22 | 90.9% | 90.9% |
| verbena_bonariensis | tier2 | 24 | 90.5% | 79.2% |
| buddleja_davidii | tier2 | 20 | 88.2% | 75.0% |
| alliaria_petiolata | tier2 | 21 | 79.2% | 90.5% |
| achyranthes_japonica | tier2 | 16 | 85.7% | 75.0% |
| arthraxon_hispidus | tier2 | 21 | 85.0% | 81.0% |
| celastrus_orbiculatus | tier2 | 28 | 59.0% | 82.1% |
| imperata_cylindrica | tier2 | 6 | 26.7% | 66.7% |
| reynoutria_japonica | tier2 | 21 | 85.0% | 81.0% |
| other_plant | other | 98 | 57.1% | 32.7% |
| not_plant | other | 66 | 75.0% | 81.8% |

## Honest limits
- These are iNaturalist photos: many are clean, well-lit close-ups by people who already knew the plant. Field accuracy on a phone in the preserve will be lower. Field Test mode exists to measure that gap; no field number is claimed until it is measured.
- Tier 2 accuracy is lower by design (fewer images per class). Tier 2 results are never shown as confirmed.
- The model does not know rare or protected natives; they come out as other_plant.
- AI suggestion, not a guarantee. Staff make the final call.
