# The technical segment of the video: what to say and show

For the teammate recording the "code" part. Target 30 seconds inside a 3-minute video. Screen-record Xcode (font 16 pt, light theme) with the files below open in tabs, and GitHub for the repo overview. Every number here is from `model/eval/` and may be said as is; nothing else may be added.

## The premise in two sentences
Autrey Mill is a 46-acre preserve in Johns Creek where the staff cannot survey every trail for invasive plants, so the app turns every visitor into a sentry: the phone spots and verifies a plant on-device, the report lands on a ranked map for staff, and the reporter is told when it is treated. The hard part was making a plant classifier honest enough to trust on a trail: calibrated, measured on photos it had never seen, and trained for shade, dusk, blur and distance.

## The 30-second version (say this, in this order, code on screen the whole time)

Total about 30 seconds, 7 shots, one sentence each. Numbers are from `model/eval/`.

1. (4 s) GitHub README top, then the three folders. "Three languages: Swift for the app, Python for the model pipeline, TypeScript for the staff dashboard."
2. (5 s) `AutreyMillSentry/Scanner/ScanDecision.swift` line 157, `decideRaw`. "Every scan ends in one of four outcomes. Confirmed needs a tuned species on top, a calibrated probability above that species' own floor, a clear margin, low entropy. Otherwise it's expert review, looks native, or rescan with a reason."
3. (4 s) Same file, line 285, `LockOnTracker.push`. "Live, it locks on only when five of the last eight frames agree, so it never flickers."
4. (6 s) `model/common.py` line 101, `FieldLight`, with `docs/images/trail-augmentation.jpg`. "Trained for the trail on purpose: dusk, flashlight, backlight, blur, far subjects. On held-out photos degraded the same way, accuracy went from seventy-two to eighty-three percent."
5. (4 s) `model/common.py` line 20, `split_for`. "Photos are split by photographer, not at random, so nothing leaks between training and test."
6. (4 s) `AutreyMillSentry/Ranger/PriorityScore.swift` line 25. "Reports are ranked by a transparent score out of a hundred: patch size, isolation, creek distance, confidence, recency, aggressiveness."
7. (3 s) Test navigator. "Seventy-five unit tests, including the real Core ML model on reference photos. Confirmed calls are ninety-seven and a half percent precise on held-out photos."

Which rubric row each shot serves: 1 = Skill (multiple text-based languages, the written definition of a 5); 2, 3, 6 = Code ("code is effectively explained") and Function; 4, 5, 7 = Code and honesty; the hand-off line to the staff segment covers Structure. Concept, Impact, Design and the live demo belong to the other segments; do not repeat them here.

## Do not say
"The preserve partnered with", "official", "approved", "endorsed", any field accuracy number, "perfect", "never wrong", "cure". If asked how accurate it is in the field: "not measured yet, the field test guide is in the repo".

## Numbers you may use (all from `model/eval/`)
62,041 training photos, 186 species, split by 9,975 photographers. Ensemble test top-1 84.4%, top-3 92.4%. Confirmed-invasive precision 97.5% at 66.5% coverage. Natives flagged 1.9%, other wild plants 9.8%. Trail-conditions mean 71.5% to 83.0%; dusk 10% to 79%; hand-shake blur 49% to 81%; far subject 34% to 75%. Common natives of the preserve: flagged 16% before, 1.1% now. 75 unit tests.
