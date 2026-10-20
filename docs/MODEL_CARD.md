# Model card: InvasiveClassifier v4 + v4b ensemble

Evaluated 2026-10-20 on the v4 test split (5896 images, 4405 observations, observers disjoint from training). Every number comes from `model/eval/compare_v4b_v4.json` (`model/compare_models.py`), `model/eval/v4_eval.json` and `model/eval/v4b_eval.json`.

## What runs on the phone
- Live view: v4 alone (EfficientNet-B0, 256 px) at about 4 frames per second, on the whole frame and on the salient region.
- Captured still: v4 (EfficientNet-B0, 256 px) and v4b (EfficientNet-B0, 288 px) each run on 4 to 5 augmented views (full frame, two centre crops, mirror, and a crop around the salient box when the plant is small); the calibrated probabilities are averaged. v4 also supplies an embedding that is compared with per-species centroids (`Resources/embeddings.json`); a call below its species' similarity floor is downgraded.
- Confirm rule: Tier 1 top class, calibrated probability at least 0.88 (per-species floors from validation), margin 0.30 over the runner-up, low entropy, inside the similarity floor.

## Head to head on the same images

| Model | Top-1 | Top-3 | Tier 1 top-1 | Tier 2 top-1 | Natives top-1 | Other plant | Confirm precision | Confirm coverage | Flagged: natives | Flagged: wild other plants | Flagged: not a plant |
|---|---|---|---|---|---|---|---|---|---|---|---|
| v4b | 83.0% | 91.7% | 88.3% | 83.6% | 85.6% | 20.2% | 96.8% | 71.4% | 2.1% | 10.9% | 3.5% |
| v4 | 82.8% | 91.5% | 85.8% | 84.0% | 85.3% | 26.8% | 96.5% | 68.3% | 2.4% | 10.9% | 5.9% |
| ensemble | 84.4% | 92.4% | 88.5% | 85.4% | 87.0% | 22.4% | 97.5% | 66.5% | 1.9% | 9.8% | 4.7% |

'Flagged' = the app would show the photo as a confirmed or possible invasive (a false alarm when the photo is a native, another plant, or not a plant). 'Coverage' = the share of true Tier 1 photos that come back confirmed; the rest go to expert review.

## Training data
- v4: 48,603 train / 7,542 val / 5,896 test images, 188 classes (14 Tier 1, 84 Tier 2, 88 natives, other_plant, not_plant); trail-camera augmentation on.
- v4b: 48,603 / 7,542 / 5,896 images, 188 classes; trail-camera augmentation on.

## Calibration and confirm floors
- Temperature scaling per model on validation (clean + degraded images); test ECE 0.0113 (v4).
- Confirm floors tuned on 7542 clean + 7540 degraded validation images. On degraded test images (5890): confirm precision 95.2%, coverage 62.3%, ECE 0.0228.

## Hardest confusions (v4, test, true -> predicted, count)
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

## Field conditions (held-out test photos degraded like trail shots)
Measured by `model/field_eval.py`: dim understory, dusk with sensor noise, flashlight, backlight, harsh sun, dappled canopy light, hand-shake and focus blur, a small far-away subject, a tight zoom, colour casts, JPEG, rotation, low resolution. Top-1 per condition:

| Condition | field_v4+v4b | field_v4 | field_v4b | field_v3+v2 |
|---|---|---|---|---|
| clean | 87.4% | 86.0% | 85.9% | 87.6% |
| dim | 86.7% | 85.5% | 85.5% | 87.1% |
| dusk_noisy | 78.7% | 77.8% | 76.7% | 10.3% |
| torch_lit | 86.9% | 84.4% | 85.5% | 73.0% |
| backlit | 86.3% | 84.3% | 85.1% | 84.9% |
| overexposed | 80.5% | 78.6% | 79.6% | 81.2% |
| dappled | 86.5% | 85.6% | 85.7% | 85.3% |
| motion_blur | 80.5% | 80.8% | 79.8% | 49.3% |
| defocus | 80.4% | 80.4% | 79.0% | 69.9% |
| far | 74.5% | 72.5% | 73.1% | 33.6% |
| far_focus | 78.1% | 74.7% | 75.7% | n/a |
| zoomed | 82.7% | 81.1% | 82.2% | 83.5% |
| cool_cast | 86.4% | 84.7% | 84.5% | 84.6% |
| warm_cast | 87.7% | 85.9% | 85.2% | 85.9% |
| jpeg30 | 85.2% | 84.1% | 83.4% | 84.7% |
| rot90 | 85.2% | 83.3% | 84.0% | 84.1% |
| lowres | 82.0% | 81.3% | 79.8% | 74.4% |
| **mean over degraded** | 83.0% | 81.5% | 81.5% | 71.5% |

## The preserve's common natives
- Before (shipped v3+v2 on 1500 held-out photos of the 74 common natives nearby): native 34.4%, not sure 48.9%, flagged as invasive 16.1% (`model/eval/local_natives_before_v3+v2.json`).
- Now: these species are named classes; their held-out accuracy is in the per-class table of `model/eval/v4_eval.json`, and the 'Flagged: natives' column above includes them.

## Honest limits
- These are iNaturalist photos, many of them clean close-ups by people who already knew the plant. Field accuracy on a phone in the preserve will be lower; Field Test mode measures it and no field number is claimed until then.
- Tier 2 results are never shown as confirmed. Unknown plants are refused rather than guessed.
- AI suggestion, not a guarantee. Staff make the final call.
