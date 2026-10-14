# Model card: InvasiveClassifier v3 + v2 ensemble

Evaluated 2026-10-14 on the v3 test split (3400 images, 2562 observations, observers disjoint from training). Every number comes from `model/eval/compare_v2_v3.json` (`model/compare_models.py`), `model/eval/v3_eval.json` and `model/eval/v2_eval.json`.

## What runs on the phone
- Live view: v3 alone (EfficientNet-B0, 256 px) at about 4 frames per second.
- Captured still: v3 and v2 (both EfficientNet-B0, 256 px) each run on 4 augmented views; the calibrated probabilities are averaged. v3 also supplies an embedding that is compared with per-species centroids (`Resources/embeddings.json`); a call below its species' similarity floor is downgraded.
- Confirm rule: Tier 1 top class, calibrated probability at least 0.90 (per-species floors from validation), margin 0.30 over the runner-up, low entropy, inside the similarity floor.

## Head to head on the same images

| Model | Top-1 | Top-3 | Tier 1 top-1 | Tier 2 top-1 | Natives top-1 | Other plant | Confirm precision | Confirm coverage | Flagged: natives | Flagged: wild other plants | Flagged: not a plant |
|---|---|---|---|---|---|---|---|---|---|---|---|
| v2 | 83.2% | 91.8% | 88.7% | 85.5% | 89.6% | 37.8% | 97.6% | 73.6% | 3.6% | 30.7% | 4.8% |
| v3 | 83.8% | 93.2% | 88.5% | 83.8% | 87.5% | 63.5% | 97.1% | 70.3% | 5.1% | 15.8% | 3.6% |
| ensemble | 84.7% | 93.9% | 89.1% | 85.5% | 89.6% | 56.0% | 98.4% | 71.4% | 3.6% | 15.4% | 3.6% |

'Flagged' = the app would show the photo as a confirmed or possible invasive (a false alarm when the photo is a native, another plant, or not a plant). 'Coverage' = the share of true Tier 1 photos that come back confirmed; the rest go to expert review.

## Training data
- v3: 29,075 train / 4,443 val / 3,400 test images, 114 classes, including 3,160 extra wild 'other plant' photos and 900 cultivated, house and garden plants as negatives.
- v2: 26,199 / 4,131 / 3,234 images of the same classes without the extra negatives.

## Calibration
- Temperature scaling per model on validation; test ECE 0.0160 (v3).

## Hardest confusions (v3, test, true -> predicted, count)
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

## Honest limits
- These are iNaturalist photos, many of them clean close-ups by people who already knew the plant. Field accuracy on a phone in the preserve will be lower; Field Test mode measures it and no field number is claimed until then.
- Tier 2 results are never shown as confirmed. Unknown plants are refused rather than guessed.
- AI suggestion, not a guarantee. Staff make the final call.
