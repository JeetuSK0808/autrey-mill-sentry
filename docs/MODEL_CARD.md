# Model card: InvasiveClassifier v3

Evaluated 2026-10-14. Every number here comes from `model/eval/v3_eval.json`, produced by `model/evaluate.py` on a held-out test split.

Backbone: timm `efficientnet_b0` (ImageNet pretrained), input 256 px, 22 epochs, AdamW + one-cycle LR, label smoothing 0.1, class-balanced sampling, strong augmentation (random resized crops, flips, rotation, colour jitter, blur, erasing). Trained on Apple MPS.

## Data and split
- Source: iNaturalist research-grade observations, photos licensed CC0 / CC-BY / CC-BY-NC only, Georgia first, then the south-eastern US, then the US. Attribution in `data/attribution.csv` (not committed) and `docs/LICENSES.md`.
- Split by observer (and therefore by observation): train 29075 / val 4443 / test 3400 images from 6526 / 711 / 835 observers. No observer appears in two splits.
- Classes: 114 (14 Tier 1, 84 Tier 2, 14 native look-alikes, other_plant, not_plant).

## Calibration
- Temperature scaling fitted on validation: T = 0.812. ECE on validation 0.0840 raw -> 0.0303 calibrated. ECE on test 0.0160.

## Headline results (test split)
| Group | Classes | Test images | Top-1 | Top-3 |
|---|---|---|---|---|
| All | 114 | 3400 | 83.8% | 93.2% |
| Tier 1 (tuned) | 14 | 772 | 88.5% | 94.8% |
| Tier 2 (broad coverage) | 84 | 1832 | 83.8% | 92.6% |
| Native look-alikes | 14 | 471 | 87.5% | 95.3% |

## The confirmed-invasive call
- Target precision for `.confirmedInvasive`: 98.0%. Chosen on validation: global threshold 0.90, margin 0.30, 13 per-class thresholds.
- Validation: precision 98.7%, coverage 67.6% (939 confirmed calls).
- **Test: precision 97.2%, coverage 70.7%** (562 confirmed calls). Coverage is the fraction of true Tier 1 photos the app confirms; the rest go to "needs expert review".
- Native or other plants wrongly confirmed as invasive on test: 0.5%.
- not_plant photos rejected (top-1 not_plant with p >= 0.5): 78.6%.

## Hardest confusions (test, true -> predicted, count)
- sonchus_oleraceus -> sonchus_asper (8)
- other_plant -> toxicodendron_radicans (7)
- other_plant -> viburnum_acerifolium (6)
- liriope_muscari -> liriope_spicata (6)
- elaeagnus_umbellata -> elaeagnus_pungens (6)
- wisteria_frutescens -> wisteria_sinensis (5)
- other_plant -> not_plant (5)
- other_plant -> ligustrum_lucidum (5)
- lygodium_japonicum -> other_plant (5)
- liriope_spicata -> liriope_muscari (5)
- ligustrum_japonicum -> ligustrum_lucidum (5)
- leucanthemum_vulgare -> other_plant (5)

## Per-class precision / recall (test)
| Class | Tier | Support | Precision | Recall |
|---|---|---|---|---|
| ligustrum_sinense | tier1 | 55 | 83.6% | 83.6% |
| mahonia_bealei | tier1 | 52 | 94.5% | 100.0% |
| lonicera_japonica | tier1 | 58 | 86.3% | 75.9% |
| wisteria_sinensis | tier1 | 64 | 87.3% | 85.9% |
| vinca_minor | tier1 | 60 | 98.2% | 91.7% |
| elaeagnus_umbellata | tier1 | 65 | 84.4% | 83.1% |
| elaeagnus_pungens | tier1 | 46 | 80.0% | 87.0% |
| rosa_multiflora | tier1 | 57 | 94.2% | 86.0% |
| hedera_helix | tier1 | 48 | 89.8% | 91.7% |
| albizia_julibrissin | tier1 | 63 | 89.9% | 98.4% |
| paulownia_tomentosa | tier1 | 35 | 70.0% | 80.0% |
| microstegium_vimineum | tier1 | 45 | 86.3% | 97.8% |
| pueraria_montana | tier1 | 60 | 88.9% | 93.3% |
| nandina_domestica | tier1 | 64 | 94.7% | 84.4% |
| lonicera_sempervirens | native | 31 | 89.7% | 83.9% |
| wisteria_frutescens | native | 22 | 66.7% | 72.7% |
| viburnum_acerifolium | native | 23 | 65.5% | 82.6% |
| viburnum_dentatum | native | 23 | 78.6% | 95.7% |
| ilex_opaca | native | 34 | 89.2% | 97.1% |
| toxicodendron_radicans | native | 38 | 78.6% | 86.8% |
| parthenocissus_quinquefolia | native | 35 | 90.0% | 77.1% |
| vitis_rotundifolia | native | 40 | 92.3% | 90.0% |
| rosa_carolina | native | 34 | 86.1% | 91.2% |
| rubus_argutus | native | 40 | 90.0% | 90.0% |
| mitchella_repens | native | 34 | 86.8% | 97.1% |
| catalpa_bignonioides | native | 50 | 89.4% | 84.0% |
| chasmanthium_latifolium | native | 25 | 95.8% | 92.0% |
| smilax_rotundifolia | native | 42 | 87.5% | 83.3% |
| ailanthus_altissima | tier2 | 22 | 73.1% | 86.4% |
| alternanthera_philoxeroides | tier2 | 13 | 85.7% | 92.3% |
| dryopteris_erythrosora | tier2 | 10 | 76.9% | 100.0% |
| eichhornia_crassipes | tier2 | 20 | 90.5% | 95.0% |
| lespedeza_bicolor | tier2 | 20 | 94.7% | 90.0% |
| lespedeza_cuneata | tier2 | 27 | 84.0% | 77.8% |
| lygodium_japonicum | tier2 | 27 | 90.5% | 70.4% |
| melia_azedarach | tier2 | 29 | 83.3% | 86.2% |
| murdannia_keisak | tier2 | 14 | 85.7% | 85.7% |
| triadica_sebifera | tier2 | 24 | 94.4% | 70.8% |
| ardisia_crenata | tier2 | 31 | 96.4% | 87.1% |
| crotalaria_spectabilis | tier2 | 17 | 94.1% | 94.1% |
| dioscorea_polystachya | tier2 | 19 | 85.7% | 94.7% |
| leucanthemum_vulgare | tier2 | 31 | 86.7% | 83.9% |
| ligustrum_lucidum | tier2 | 28 | 63.2% | 85.7% |
| lonicera_maackii | tier2 | 26 | 95.0% | 73.1% |
| miscanthus_sinensis | tier2 | 27 | 85.7% | 88.9% |
| myriophyllum_aquaticum | tier2 | 21 | 90.9% | 95.2% |
| nasturtium_officinale | tier2 | 18 | 90.0% | 100.0% |
| phyllostachys_aurea | tier2 | 28 | 85.7% | 85.7% |
| sesbania_punicea | tier2 | 19 | 77.3% | 89.5% |
| spiraea_japonica | tier2 | 24 | 87.5% | 87.5% |
| vinca_major | tier2 | 16 | 84.2% | 100.0% |
| vitex_rotundifolia | tier2 | 13 | 86.7% | 100.0% |
| ajuga_reptans | tier2 | 29 | 87.5% | 96.6% |
| ampelopsis_glandulosa | tier2 | 21 | 81.8% | 85.7% |
| anthoxanthum_odoratum | tier2 | 21 | 83.3% | 71.4% |
| arundo_donax | tier2 | 20 | 73.9% | 85.0% |
| berberis_thunbergii | tier2 | 19 | 94.1% | 84.2% |
| broussonetia_papyrifera | tier2 | 17 | 73.7% | 82.4% |
| carduus_nutans | tier2 | 35 | 92.1% | 100.0% |
| centaurea_cyanus | tier2 | 25 | 95.8% | 92.0% |
| citrus_trifoliata | tier2 | 13 | 76.5% | 100.0% |
| clematis_terniflora | tier2 | 26 | 100.0% | 65.4% |
| colocasia_esculenta | tier2 | 7 | 85.7% | 85.7% |
| daucus_carota | tier2 | 20 | 86.7% | 65.0% |
| euonymus_fortunei | tier2 | 33 | 96.2% | 75.8% |
| hemerocallis_fulva | tier2 | 23 | 100.0% | 95.7% |
| hibiscus_syriacus | tier2 | 27 | 91.7% | 81.5% |
| ligustrum_japonicum | tier2 | 25 | 81.0% | 68.0% |
| liriope_muscari | tier2 | 22 | 71.4% | 68.2% |
| lonicera_fragrantissima | tier2 | 25 | 82.1% | 92.0% |
| morus_alba | tier2 | 29 | 94.7% | 62.1% |
| paspalum_urvillei | tier2 | 35 | 96.3% | 74.3% |
| perilla_frutescens | tier2 | 22 | 88.0% | 100.0% |
| phragmites_australis | tier2 | 18 | 70.6% | 66.7% |
| pyrus_calleryana | tier2 | 20 | 84.2% | 80.0% |
| rubus_armeniacus | tier2 | 24 | 86.4% | 79.2% |
| securigera_varia | tier2 | 22 | 87.5% | 95.5% |
| solanum_viarum | tier2 | 27 | 88.5% | 85.2% |
| sorghum_halepense | tier2 | 21 | 75.0% | 57.1% |
| vernicia_fordii | tier2 | 23 | 78.9% | 65.2% |
| akebia_quinata | tier2 | 37 | 90.6% | 78.4% |
| allium_vineale | tier2 | 11 | 77.8% | 63.6% |
| artemisia_vulgaris | tier2 | 12 | 100.0% | 58.3% |
| cirsium_vulgare | tier2 | 31 | 90.0% | 87.1% |
| euonymus_alatus | tier2 | 23 | 76.9% | 87.0% |
| fatoua_villosa | tier2 | 11 | 76.9% | 90.9% |
| firmiana_simplex | tier2 | 22 | 83.3% | 90.9% |
| ilex_cornuta | tier2 | 20 | 94.4% | 85.0% |
| ilex_crenata | tier2 | 34 | 82.1% | 67.6% |
| ipomoea_coccinea | tier2 | 14 | 86.7% | 92.9% |
| ipomoea_purpurea | tier2 | 10 | 83.3% | 100.0% |
| jacquemontia_tamnifolia | tier2 | 34 | 96.7% | 85.3% |
| kummerowia_stipulacea | tier2 | 16 | 100.0% | 93.8% |
| kummerowia_striata | tier2 | 16 | 94.1% | 100.0% |
| liriope_spicata | tier2 | 27 | 66.7% | 74.1% |
| persicaria_longiseta | tier2 | 21 | 86.4% | 90.5% |
| quercus_acutissima | tier2 | 15 | 60.0% | 80.0% |
| rosa_laevigata | tier2 | 24 | 88.0% | 91.7% |
| rubus_phoenicolasius | tier2 | 23 | 92.0% | 100.0% |
| setaria_pumila | tier2 | 20 | 94.1% | 80.0% |
| sonchus_asper | tier2 | 15 | 61.9% | 86.7% |
| sonchus_oleraceus | tier2 | 18 | 81.8% | 50.0% |
| torilis_arvensis | tier2 | 26 | 76.7% | 88.5% |
| verbascum_thapsus | tier2 | 22 | 95.0% | 86.4% |
| verbena_bonariensis | tier2 | 24 | 84.6% | 91.7% |
| buddleja_davidii | tier2 | 20 | 81.0% | 85.0% |
| alliaria_petiolata | tier2 | 21 | 90.9% | 95.2% |
| achyranthes_japonica | tier2 | 16 | 86.7% | 81.2% |
| arthraxon_hispidus | tier2 | 21 | 86.4% | 90.5% |
| celastrus_orbiculatus | tier2 | 28 | 71.9% | 82.1% |
| imperata_cylindrica | tier2 | 6 | 41.7% | 83.3% |
| reynoutria_japonica | tier2 | 21 | 76.9% | 95.2% |
| other_plant | other | 241 | 61.7% | 63.5% |
| not_plant | other | 84 | 79.5% | 78.6% |

## Honest limits
- These are iNaturalist photos: many are clean, well-lit close-ups by people who already knew the plant. Field accuracy on a phone in the preserve will be lower. Field Test mode exists to measure that gap; no field number is claimed until it is measured.
- Tier 2 accuracy is lower by design (fewer images per class). Tier 2 results are never shown as confirmed.
- The model does not know rare or protected natives; they come out as other_plant.
- AI suggestion, not a guarantee. Staff make the final call.
