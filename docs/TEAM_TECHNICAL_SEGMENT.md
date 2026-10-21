# The technical segment of the video: what to say and show

For the teammate recording the "code" part. Target 35 to 45 seconds inside a 3-minute video. Screen-record Xcode (font 16 pt, light theme) with the files below open in tabs, and GitHub for the repo overview. Every number here is from `model/eval/` and may be said as is; nothing else may be added.

## The premise in two sentences
Autrey Mill is a 46-acre preserve in Johns Creek where the staff cannot survey every trail for invasive plants, so the app turns every visitor into a sentry: the phone spots and verifies a plant on-device, the report lands on a ranked map for staff, and the reporter is told when it is treated. The hard part was making a plant classifier honest enough to trust on a trail: calibrated, measured on photos it had never seen, and trained for shade, dusk, blur and distance.

## One bullet per rubric row (say these almost word for word)

Official CAC rubric (Concept, Design, Skill, scored 1 to 5) and the newer criteria (Ideology, Impact, Structure, Function, Code, User Interface):

- **Concept / Ideology, "does the app address a specific problem, how creative is the solution":** "The problem is early detection of invasive plants on 46 acres with a staff of a few. The solution is a closed loop, not a plant ID app: spot, verify, act, tell. The report becomes a ranked job for staff and the visitor gets told when it's done."
- **Impact, "strong explanation of its impact":** "Small patches are cheap to remove and big ones aren't. The rank puts small, isolated patches near the creek first, because that's where early detection pays off, and every visitor's phone becomes a survey."
- **Function, "the app is functional":** "It runs on the phone with no signal: live camera at four frames a second, lock-on when five of the last eight frames agree, then a captured still goes through two Core ML models and exactly one of four outcomes." (Show the live scan clip from the trail right before or after this line.)
- **Code, "code is effectively explained":** walk one path end to end, in this order, one sentence each, the function on screen while you speak:
  1. `AutreyMillSentry/Scanner/FrameQuality.swift`: "Every frame is measured first: sharpness, exposure, where the plant is with Vision saliency, and whether a person is in the shot, which is refused."
  2. `AutreyMillSentry/Scanner/ScanDecision.swift` line 157, `decideRaw`: "Four outcomes. Confirmed needs a tuned species on top, a calibrated probability above that species' own floor, a 0.30 margin over the runner-up and low entropy. Otherwise it's expert review, looks native, or rescan with the reason."
  3. `AutreyMillSentry/Scanner/ScanDecision.swift` line 285, `LockOnTracker.push`: "The lock-on: agreement over a window of frames so the screen never flickers between species."
  4. `model/common.py` line 101, `FieldLight`: "The models are trained for the trail on purpose: dusk with sensor noise, flashlight, backlight, dappled light, hand-shake, far subjects. On held-out photos degraded the same way, accuracy went from 71.5 to 83.0 percent, and in dusk from 10 to 79."
  5. `model/common.py` line 20, `split_for`: "Photos are split by photographer, not at random, so one person's near-duplicates can never leak between training and test and inflate the score."
  6. `AutreyMillSentry/Ranger/PriorityScore.swift` line 25, `score`: "The rank is a transparent score out of 100: patch size, isolation, creek distance, model confidence, recency, and how aggressive the species is. Treatment is the staff's call; the app never recommends a method."
  7. `AutreyMillSentryTests/` in the navigator: "Seventy-five unit tests cover the decision, the lock-on, the rank, the geometry and the real Core ML model on reference photos."
- **Skill, "multiple text-based programming languages" (that is the written definition of a 5):** "Three languages: Swift and SwiftUI for the app, Python with PyTorch for the training pipeline and evaluation, TypeScript with Next.js for the staff dashboard." Show each repo folder for a second while saying it.
- **Design / User Interface, "intuitive UI, thought given to design":** "Apple's Human Interface Guidelines throughout: Scan in the middle of the tab bar, forty-four point targets, Dynamic Type to the largest size, VoiceOver labels, status pins by shape and colour, dark mode, all verified with Xcode's accessibility audit." (Two seconds of the dark-mode map.)
- **Structure, "video explains all aspects of the app":** this segment covers scanner, model, rank and dashboard code; the other segments cover the problem, the live demo, privacy and the staff loop. Do not repeat them, hand off cleanly: "Here's what that looks like for the staff" and cut.
- **Honesty (judges are CS professionals, this is where credibility is won):** "The confirmed call is 97.5 percent precise on held-out photos. Field accuracy on the trail isn't measured yet, and the app says so on its About screen until it is. Every number the app shows comes from an evaluation file; nothing is typed in."

## What to include on screen, in order
1. GitHub repo README top: icon, screenshots row, the three language badges (3 s).
2. Xcode: `FrameQuality.swift`, `ScanDecision.swift` (`decideRaw`, then scroll to `LockOnTracker.push`), `PriorityScore.swift` (18 s).
3. `model/common.py` (`FieldLight`, then `split_for`) and the training augmentation sheet `docs/images/trail-augmentation.jpg` (10 s).
4. `docs/MODEL_CARD.md` table "Trail conditions" or the app's About screen (5 s).
5. Test navigator with the 75 tests, one second.
6. `dashboard/app/api/reports/route.ts` for one second while saying "TypeScript, Next.js".

## Do not say
"The preserve partnered with", "official", "approved", "endorsed", any field accuracy number, "perfect", "never wrong", "cure". If asked how accurate it is in the field: "not measured yet, the field test guide is in the repo".

## Numbers you may use (all from `model/eval/`)
62,041 training photos, 186 species, split by 9,975 photographers. Ensemble test top-1 84.4%, top-3 92.4%. Confirmed-invasive precision 97.5% at 66.5% coverage. Natives flagged 1.9%, other wild plants 9.8%. Trail-conditions mean 71.5% to 83.0%; dusk 10% to 79%; hand-shake blur 49% to 81%; far subject 34% to 75%. Common natives of the preserve: flagged 16% before, 1.1% now. 75 unit tests.
