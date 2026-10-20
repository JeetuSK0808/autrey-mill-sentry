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

## Second visit (after the v4 scanner, 20 Oct or later): lighting and common natives
The first field report was "it does not register a plant". The fix was measured on degraded photos (`model/eval/field_*.json`), but only the trail proves it. On this visit:
- **Turn on the overlay**: Reports > gear > Developer > **Scan diagnostics**. Two lines appear over the camera: `live` (top three guesses the model sees right now) and `gate` (sharpness, light, subject size, motion, and which check, if any, is holding things back). If a plant does not register, photograph the screen or tap **Export scan diagnostics** and AirDrop the JSON.
- **Same plant, four lights**: pick one privet and one sweetgum (or any two plants near the mill) and scan each in open sun, in deep shade, backlit against the sky, and at dusk or with the flashlight. Note which of the four fails, if any.
- **Common natives, not just invasives**: scan 20+ of the plants in the Learn tab's "Common natives nearby" (sweetgum, tulip poplar, beech, dogwood, Christmas fern, mayapple, river cane along the creek...). The app should say "Looks like native ..." with no report. Every one it calls "possible invasive" or "not sure" is a data point: set the true label.
- **Distance**: scan one plant from 1 ft, 3 ft and 8 ft. The app should hold its answer at 3 ft and ask you to move closer at 8 ft, not invent a species.
- **Tap to focus**: tap the leaf you mean on the camera view when the background is busy; the exposure follows the tap too.

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
