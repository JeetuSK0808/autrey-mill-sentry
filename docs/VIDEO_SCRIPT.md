# Video: what the judges score, what must be on screen, and a sample script

Hard rules from the Congressional App Challenge: **one video, 3 minutes maximum**, it must **show the app working** and **explain how it was coded**. Judges (volunteer teachers and CS professionals) watch the video, read the short answers, and score three areas. Every number below comes from `model/eval/*.json`; nothing else may be said.

## The rubric, and the on-screen moment for each row

CAC scores **Quality of the idea**, **Implementation of the idea**, and **Demonstrated excellence of coding**. District judges also weigh creativity, a real problem, design thought, and whether it actually works (`BUILT-PROMPT.md`, Rubric map).

| Rubric row | Judges ask | Must appear on screen | Seconds |
|---|---|---|---|
| Real problem, local impact | Is there a concrete user? | Trail clip at Autrey Mill, a privet thicket, the preserve's own list of 14 invasives | 0:00 to 0:20 |
| Creativity, originality | Not just another plant ID app? | The loop: Spot, Verify, Act, Tell. A report becomes a ranked job for staff and the reporter gets told | throughout, named once at 0:20 |
| Functionality | Does it work live? | Live scan on the real phone: guidance text, lock-on, capture, result. A bad shot getting a specific "move closer" or "hold steady". A native getting "no report needed" | 0:35 to 1:15 |
| Technical difficulty | Something hard, solved well | Code moment: the decision function and the lock-on window, the trail-condition training, the observer-level split, the calibrated confirm rule. Real numbers from the model card | 1:15 to 1:50 |
| Design, user experience | Thought given to design? | Clean tabs, the map with real trails, status pins by shape and colour, dark mode for two seconds, big buttons on the staff dashboard | 1:50 to 2:05 |
| Responsible design | Privacy, safety, honesty | "No accounts, nothing leaves the phone until you tap Send", person check, "AI suggestion, not a guarantee" footer, About card with the accuracy gap | 2:05 to 2:20 |
| Staff value | Does someone use the output? | Send to staff, the dashboard on a laptop, Treated, the notification on the phone | 2:20 to 2:45 |

Length target **2:45**. Leave the last 10 seconds for the end card.

## The code moments (open these in Xcode, zoom the font to 16 pt, 6 to 8 seconds each)

1. `AutreyMillSentry/Scanner/ScanDecision.swift:157` `decideRaw`: the four outcomes. Scroll so `case .tier1:` (line 175) and `case .native, .other:` (line 184) are both visible. Say: confirmed needs a Tier 1 top class, a calibrated probability above its own floor, a 0.30 margin over the runner-up, low entropy. Anything else goes to expert review, "looks native", or a rescan with a reason.
2. `AutreyMillSentry/Scanner/ScanDecision.swift:285` `LockOnTracker.push`: 5 of the last 8 frames must agree before the app says "locked on". That is the visual judges just saw.
3. `model/common.py:101` `class FieldLight`: the trail-camera training. Dusk, flashlight, backlight, dappled canopy light, hand-shake, far subject. Say the numbers that came out of it.
4. `model/common.py:20` `split_for`: one line, the observer-level split. Say why: one photographer's near-duplicates would leak between train and test and inflate the score.
5. `AutreyMillSentry/Ranger/PriorityScore.swift:25` `score`: the transparent early-detection rank, weights that sum to 100.

Optional sixth: `AutreyMillSentryTests/` in the navigator, 75 unit tests, one second.

## Sample script (voice-over, first person, plain)

Record the voice separately, then lay it over. Timecodes are targets, not law.

**0:00 On-site clip: the trail, then a wall of privet. Title card "Autrey Mill Sentry".**
"This is Autrey Mill Nature Preserve in Johns Creek. I live next to it. The preserve's own volunteers list fourteen invasive plants here, and the staff can't walk forty-six acres every week."

**0:12 Cut between a tiny privet seedling and a huge thicket.**
"Small patches are cheap to remove. Big ones aren't. So the whole game is finding them early. My idea is that every visitor becomes a sentry."

**0:22 Screen recording: launch animation, onboarding page with the promise.**
"The loop is spot, verify, act, tell. No accounts, no tracking, and nothing leaves your phone until you tap Send."

**0:35 Screen recording on the trail: Scan tab, walk toward privet. Guidance reads "Move closer to the leaves", then "Plant in view, hold steady", the frame locks, haptic, tap, result: "Chinese privet. Confirmed invasive by the on-device model." Tap Save.**
"The scanner runs on the phone. It meters and focuses where I tap, it watches the whole frame and the part that looks like a plant, and it needs five of the last eight frames to agree before it locks on. Then it tells me what it thinks and how sure it is."

**0:55 Deliberately blurry shot, then too far: the rescan screen with the specific instruction. Then a sweetgum: "Looks like native American sweetgum. No report needed." with its field marks.**
"If the shot is bad, it tells me why. If it isn't sure, the report goes to expert review instead of a guess. And it knows the preserve's own plants by name, eighty-eight natives, so a sweetgum is a sweetgum, not a false alarm."

**1:15 Xcode: `decideRaw` in ScanDecision.swift, then `LockOnTracker.push`.**
"This is the decision. Four outcomes. Confirmed needs a tuned species on top, a calibrated probability above that species' own floor, a clear margin over the runner-up, and low entropy. Everything else is expert review, looks native, or rescan with a reason. And this is the lock-on: agreement over a window of frames, so the screen never flickers."

**1:30 Xcode: `FieldLight` in common.py, then `split_for`.**
"My first field test failed in the shade. So I trained for the trail on purpose: dusk with sensor noise, flashlight, backlight, dappled light, hand-shake, a far-away subject. On held-out photos degraded the same way, accuracy went from seventy-two to eighty-three percent, and in dusk from ten to seventy-nine. I split the photos by photographer, not at random, so one person's near-duplicates can't leak between training and test and inflate the score."

**1:45 About screen: "How accurate is this?" card.**
"Sixty-two thousand licensed iNaturalist photos, one hundred eighty-six species. On held-out photos the confirmed call is ninety-seven and a half percent precise. The app shows only numbers that came out of a real evaluation file, and it says field accuracy is not measured yet until it is."

**1:55 Map tab: pin on the real trail map, tap it, detail sheet. Two seconds of dark mode. Plant deck.**
"Every report lands on a real map of the preserve, trails and creek from OpenStreetMap, pins shaped and coloured by status. And there's a deck of every plant it knows, so people learn as they walk."

**2:05 Onboarding privacy page, the person check ("Please retake without people"), the footer "AI suggestion, not a guarantee".**
"It refuses to capture people. It asks for location only while you scan, and you can delete everything in one tap. Every result says it's a suggestion, not a guarantee. Staff make the final call."

**2:20 Reports > Send > "Send to preserve staff". Cut to a laptop: the dashboard, the report on the map and in the ranked list. Tap Treated. Back on the phone: the notification banner.**
"When I send, the report lands on a dashboard any ranger can open from a link, ranked so small, isolated patches near the creek come first, because that's early detection. When staff mark it treated, the reporter gets told. The loop closes."

**2:40 On-site clip: on the trail, phone in hand. End card: "Autrey Mill Sentry. Built for Autrey Mill Nature Preserve by Jeetu SK."**
"Spot, verify, act, tell. Every visitor a sentry."

## Do not say
"The preserve partnered with", "official", "approved", "endorsed", any field accuracy number (none is measured), "cure", "kills millions", anything not in a `model/eval` file. If the field test happens before filming, add one sentence with the measured field number and the gap, honestly, whatever it is.

## Filming list
- On site, daylight, no people in frame: privet wall, privet seedling, English ivy on a trunk, a sweetgum or beech, one scan in deep shade with the flashlight coming on, the creek, a trail sign, Jeetu walking.
- Phone: Settings > Control Center > Screen Recording; location on; airplane mode off for the Send step.
- Laptop: browser on https://mill-sentry.vercel.app, board cleared beforehand (open a test report, Delete).
- Xcode: font 16 pt, light theme, the five files above open in tabs so the cuts are instant.
