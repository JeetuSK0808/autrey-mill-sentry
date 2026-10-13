# Field test guide (for Jeetu, one afternoon at the preserve)

Goal: 100+ scans at Autrey Mill with a person who knows the plants checking each one, so the app can report a real field accuracy next to the held-out number. No number goes into the app or the video until this CSV exists.

## Before you go
1. Install the current build on the phone (Claude does this once the phone is connected). Open the app once at home and allow Camera and Location.
2. Reports tab > gear > Evaluation > **Field Test mode** on.
3. Charge the phone. Bring the checker (staff member or trained volunteer), water, and the printed Tier 1 list from `model/CLASSES.md`.

## On the trail
- Stay on marked trails. Do not touch or pick plants. No people in frame.
- For each plant: scan it live (let it lock on, tap the shutter). On the result screen, scroll to **Field test: true label** and pick what the checker says it is. Then **Save report**. Rescans count too: if the app asks to rescan, try once more, and if it still cannot decide, use **Report anyway for expert review** and set the true label.
- Aim for variety: at least 5 of each Tier 1 species you can find, 20+ native look-alikes (coral honeysuckle, Virginia creeper, poison ivy from a distance, viburnums), 10+ random other plants, a few deliberately bad shots (too far, blurry, pointing at bark or sky) to test the rescan logic.
- Note the light: do some scans in deep shade and some in sun.

## Afterwards
1. Reports > gear > Evaluation > **Export field test CSV** > AirDrop it to the Mac.
2. Run:

```bash
~/miniforge3/bin/python3 -I ~/autrey-mill-sentry/tools/field_accuracy.py ~/Downloads/field_test.csv
```

3. That writes `model/eval/field_test.json` and puts the field accuracy and photo count into `Resources/model_card.json`. Rebuild, and the About card shows "Field accuracy at the preserve". The gap between held-out and field accuracy goes into `docs/MODEL_CARD.md` and the video, honestly, whatever it is.

## What counts as what
- `claimAccuracy`: of the scans where the app named a species (not "needs expert review"), the fraction the checker agreed with.
- `sentToExpertReview`: scans the app refused to name. Those are not wrong, they are deferred; the CSV records what they really were.
- Everything is computed by the script from the CSV. Nothing is typed in by hand.
