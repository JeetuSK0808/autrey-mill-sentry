# The code segment: screen recording of the GitHub repo, about 33 seconds

Who: the teammate presenting the technical side. What: a screen recording of the repository in a browser, eight stops, one line of narration per stop. Every number is from `model/eval/` and may be said as written; add nothing else.

## Setup (5 minutes, before recording)
1. Accept the GitHub collaborator invite, sign in, open Chrome or Safari in a fresh window, hide the bookmarks bar, set page zoom to 125%.
2. Open these eight tabs in this exact order (each one lands scrolled to the right lines):
   1. https://github.com/JeetuSK0808/autrey-mill-sentry
   2. https://github.com/JeetuSK0808/autrey-mill-sentry/blob/main/AutreyMillSentry/Scanner/ScanDecision.swift#L157-L200
   3. https://github.com/JeetuSK0808/autrey-mill-sentry/blob/main/AutreyMillSentry/Scanner/ScanDecision.swift#L285-L300
   4. https://github.com/JeetuSK0808/autrey-mill-sentry/blob/main/model/common.py#L101-L137
   5. https://github.com/JeetuSK0808/autrey-mill-sentry/blob/main/model/common.py#L20-L23
   6. https://github.com/JeetuSK0808/autrey-mill-sentry/blob/main/AutreyMillSentry/Ranger/PriorityScore.swift#L25-L60
   7. https://github.com/JeetuSK0808/autrey-mill-sentry/blob/main/dashboard/app/api/reports/route.ts#L39-L70
   8. https://github.com/JeetuSK0808/autrey-mill-sentry/tree/main/AutreyMillSentryTests
3. Start the screen recording (macOS: Shift+Cmd+5, record the window, 1080p). Record the voice at the same time or separately, your choice; speak at a normal pace, no filler.
4. Rule for every stop: switch tab, wait one second in silence, say the line, do not scroll while speaking unless the step says so.

## The eight stops

**Stop 1, tab 1, README (3 s).** Let the screenshot row and the three language badges sit on screen.
Say: "Autrey Mill Sentry is a full stack. Swift and SwiftUI on the device, a PyTorch pipeline behind the model, and a Next.js dashboard for the preserve's staff."

**Stop 2, tab 2, `ScanDecision.swift` lines 157 to 200, `decideRaw` (6 s).** Highlighted lines are on screen. Mid-sentence, scroll down slowly about half a screen so `case .tier1:` and `case .native, .other:` both pass through view.
Say: "Every scan resolves to exactly one of four outcomes. A confirmed call requires a tuned species on top, a calibrated probability above that species' own validation-tuned floor, a thirty-point margin over the runner-up, and low entropy. Anything weaker is routed to expert review, read as native, or sent back for a rescan with the reason."

**Stop 3, tab 3, `ScanDecision.swift` lines 285 to 300, `LockOnTracker.push` (4 s).** No scrolling.
Say: "Live, the tracker demands agreement on five of the last eight frames before it locks, so the interface never flickers between species."

**Stop 4, tab 4, `model/common.py` lines 101 to 137, `FieldLight` (6 s).** Scroll slowly through the class while speaking so the dusk, dappled, flashlight and motion-blur blocks pass by.
Say: "The models are trained under trail conditions by design: dusk with sensor noise, flashlight, backlight, dappled canopy light, motion blur, far-away subjects. On held-out photos degraded the same way, top-one accuracy moved from seventy-one point five to eighty-three percent."

**Stop 5, tab 5, `model/common.py` lines 20 to 23, `split_for` (4 s).** No scrolling.
Say: "Validation and test are split by photographer, not by photo, so near-duplicates can never leak across the split and inflate the score."

**Stop 6, tab 6, `PriorityScore.swift` lines 25 to 60, `score` (4 s).** Scroll slowly so the factor list passes by.
Say: "Staff get a transparent priority out of one hundred: patch size, isolation, creek proximity, model confidence, recency, species aggressiveness. Treatment stays a human decision."

**Stop 7, tab 7, `dashboard/app/api/reports/route.ts` line 39, the upload handler (3 s).** No scrolling.
Say: "The dashboard API validates every upload, carries no identity, and exposes nothing but the status back to the phone."

**Stop 8, tab 8, the tests folder (3 s).** Hover the five test files.
Say: "Seventy-five unit tests, including the real Core ML models on reference photos. Confirmed calls measure ninety-seven point five percent precision on held-out data."

Hand off to the staff-loop segment: cut straight to the phone's Send sheet. No closing line.

## Which rubric row each stop serves
- Skill, "multiple text-based programming languages" (the written definition of a 5): stop 1, reinforced by stops 4 and 7.
- Code, "code is effectively explained": stops 2, 3, 4, 5, 6, 7.
- Function, "the app is functional": stops 2 and 3, paired with the live demo in the previous segment.
- Concept, Impact, Design, User Interface, Structure: covered in the other segments; do not repeat them here.

## Do not say
"Partnered", "official", "approved", "endorsed", "perfect", "never wrong", "AI" as a selling point, any field accuracy figure (none is measured yet; the app says so until a field test CSV exists).

## If a judge asks later
Why observer-level split: "random splits leak one photographer's near-duplicate shots into test; ours are disjoint by observer, 8,040 / 907 / 1,028 observers." Why calibrate: "temperature scaling on validation, including degraded copies, so the confidence bar means the same thing in shade and sun; expected calibration error 0.011 clean, 0.023 degraded." Why two models: "an ensemble of a 256-pixel and a 288-pixel network with different seeds; on the same test images it lifts Tier 1 accuracy and cuts natives flagged as invasive to 1.9 percent."
