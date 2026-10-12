# Claude Code prompt: Autrey Mill Sentry (iOS app for the Congressional App Challenge)

Paste everything below the line into Claude Code (desktop app, Code tab, run natively on Jeetu's Mac so it can use Xcode, MPS and his browser). Create the project folder first: `~/autrey-mill-sentry`.

---

# MISSION

Build **Autrey Mill Sentry**, a native iOS app (Swift, SwiftUI, Core ML, MapKit) for **Autrey Mill Nature Preserve & Heritage Center** (9770 Autrey Mill Road, Johns Creek, GA 30022). It must run on Jeetu's physical iPhone for a 3-minute demo video and be submitted to the **Congressional App Challenge (CAC)**. **Deadline: Mon Oct 26, 2026, 12:00 pm ET** (source code + video + short answers). Today is Mon Oct 12. Target: a demoable build with a working scanner by **Fri Oct 16**, feature complete by **Oct 20**, polish and video by **Oct 24**.

Read first: `~/.claude/CLAUDE.md`, then the vault note `The Archives/.../Congressional App Challenge - Autrey Mill invasive app.md` if present. Create `~/autrey-mill-sentry/HANDOFF.md` (status, how to build and run, ranked next steps) and keep it updated, like every other project repo.

## Who this is for
- **Jeetu SK** (Satyajeeth Suresh Kannan), a high school junior in Johns Creek and a minor. Sign any user-facing credit as "Jeetu SK". He lives next to the preserve. Preserve staff said in person on 12 Oct that the idea "sounds like a good idea". That is the only endorsement we have. Never write or imply that the preserve built, approved, partnered on, or officially endorses the app. Use "built for Autrey Mill Nature Preserve" and "student project".
- **Judges** are volunteer teachers and CS professionals who watch a video of at most 3 minutes, read short answers (what inspired you, what technical challenge you faced and how you solved it), and score against a rubric. District rubrics emphasise: how creative the app is, whether it addresses a real problem, thought given to design, and whether it actually works. A competent app solving a concrete local problem beats an ambitious app with no real user.

## The problem and pitch
Invasive plants are crowding out native plants in the preserve. Staff and volunteers cannot survey 46 acres constantly. Early detection is the cheapest and most effective way to fight invasives, because small isolated patches are easy to remove and large ones are not. Pitch line: **"Every visitor becomes a sentry for the preserve."** (The name Autrey Mill Sentry ties to this.)

Claim discipline: do NOT claim invasives "kill millions of animals". Use the defensible version: invasive plants like privet, English ivy and kudzu crowd out native understory plants, which reduces the insects, berries and cover that local wildlife depend on. Cite one real source (UGA Center for Invasive Species and Ecosystem Health, USFWS, or Georgia Exotic Pest Plant Council) in the About screen and in `docs/SOURCES.md`. Verify the source actually says it before citing.

## The core loop (this is the app)
**Spot, Verify, Act, Tell.**
1. **Spot:** the visitor points the camera at a plant. The scanner runs on-device, checks the view is usable, and identifies it.
2. **Verify:** if it is not clearly framed, the app asks the user to rescan and says exactly why. If the model is unsure, the report goes to an "Needs expert review" queue instead of being called an invasive.
3. **Act:** confirmed reports appear on a ranked list and map for staff, who mark them confirmed, treated or dismissed.
4. **Tell:** when staff mark a report treated, the reporter gets a notification ("Your privet report was treated").

---

# HARD RULES (never break)

1. **No money.** No paid Apple Developer Program, no paid APIs, GPUs, hosting tiers or subscriptions. Everything must work with a free Apple ID provisioning profile and free tiers. If paying is the only way to do something, say so in one sentence and let Jeetu decide.
2. **Never type, print or store passwords, tokens or API keys.** Apple ID sign-in, signing team selection, trusting the developer certificate on the phone, and every permission tap are Jeetu's. Do not commit secrets. No `.env` with keys in the repo.
3. **Integrity.** Never fabricate or inflate accuracy numbers, field results, pilot counts, quotes or credentials. Every number shown in the app, docs or video script must come from a file produced by a real evaluation run (`model/eval/*.json`). If a metric is not measured yet, the app shows nothing for it. Report the gap between held-out accuracy and field accuracy honestly.
4. **Work directly.** Do not launch lots of subagents. One or two only when clearly useful.
5. **Private by default.** Git repo local only, no remote created without Jeetu. Do not commit training images, the Apple signing files, or anything of his dad's. (CAC needs source code submitted, so keep the repo clean enough to hand over: no secrets, no datasets, a README, a license note.)
6. **Compute reality.** Heavy work (model training, Xcode builds) runs natively on the Mac. Before training, check `ps` for other long jobs (QuantiPhy, Fusion, FLAG). If another long job runs, use `nice` and `VECLIB_MAXIMUM_THREADS=1`. The lid must stay open for long runs. On macOS use `gunzip -c`, not `zcat`.
7. **Do not touch** other project folders. Request access only to `~/autrey-mill-sentry` and the vault.

---

# STEP 0: ENVIRONMENT CHECK (do this before writing code)

Run and report: `xcodebuild -version`, `xcode-select -p`, `xcrun simctl list devices available | head`, `swift --version`, free disk space, and `~/miniforge3/bin/python3 --version`. Notes: no Homebrew, Python is `~/miniforge3/bin/python3`, `uv` is in `~/.local/bin`, Node is at `~/.local/node/bin`.

**Creating the Xcode project:** the most reliable path is for Jeetu to create an empty project once in Xcode (File > New > Project > iOS App, product name `AutreyMillSentry`, interface SwiftUI, language Swift, storage SwiftData off or on as you prefer, save in `~/autrey-mill-sentry`, select his personal team under Signing). Ask him to do this and wait, then take over from there. If he prefers, fall back to generating the project with XcodeGen by downloading its release binary into `~/.local/bin` (no Homebrew), but he still has to pick the signing team. Deployment target **iOS 17.0** (SwiftData, Observation, new SwiftUI MapKit API). Use only first-party frameworks plus the Core ML model. **No third-party Swift packages, no analytics, no ad SDKs.**

Find out which iPhone and iOS version he has (ask once). Camera needs a real device. The Simulator has no camera, so the scanner also supports **photo-picker input** (this also lets judges or the video test with saved photos, and lets you run automated tests).

Free provisioning limits: apps signed with a free Apple ID expire after **7 days** and are limited to a few apps. Tell Jeetu the install date matters: install the final build on **Oct 22 or later** so it stays valid through the Oct 26 submission, and do not reinstall mid-recording. Developer Mode must be on (Settings > Privacy & Security).

---

# ARCHITECTURE

- **UI:** SwiftUI, MVVM-ish with Observation (`@Observable`). Tab bar: **Map, Scan (center, prominent), Reports, Learn, Visit**. Settings and Privacy via a gear in Reports. Staff view ("Ranger") is a mode in Settings (see below).
- **Persistence:** SwiftData for reports and settings. Photos saved as JPEG files in the app's Application Support directory (not the photo library) with EXIF location stripped; coordinates live in the database.
- **ML:** one Core ML image classifier (`InvasiveClassifier.mlpackage`) run through Vision (`VNCoreMLRequest`). Classifier sits behind a protocol (`PlantClassifying`) with a `MockClassifier` so the UI can be built before the real model is ready.
- **Location:** `CLLocationManager`, **When In Use only**, no background location.
- **Map:** SwiftUI `Map` (MapKit) with custom overlays from bundled GeoJSON.
- **Sending reports:** local-first. "Send to preserve" builds a report package (PDF summary + CSV + photos) and opens the iOS share sheet or mail composer addressed to `Config.rangerEmail`. That constant is a clearly marked placeholder (`TODO_RANGER_EMAIL`) that Jeetu fills in once staff give an address. Never invent an address. Put a `ReportSyncing` protocol in place with a `LocalOnlySync` implementation so a free-tier backend could be added later; do NOT build the backend now.
- **Tell step honesty:** with no backend, the "treated" notification is a **local notification** fired when status changes on the device, which lets the loop be demonstrated end to end on one phone using the Ranger mode. In docs and the video script describe it truthfully ("in the pilot the preserve's status updates reach the reporter" is only true if a sync exists, so say "the app notifies the reporter when staff mark a report treated" and show it on-device).
- **Tests:** XCTest unit tests for the decision logic, ranking, geofence, duplicate merging and CSV/PDF export. UI test for the happy path using a photo-picker fixture.

---

# FEATURE 1: INTERACTIVE MAP OF THE PRESERVE

Goal: a real, accurate map of Autrey Mill with trails, boundary, creek and the user's position, plus report pins.

**Fetch the data (use whatever means works: shell `curl`, Python, or the Claude in Chrome browser tools; pick the Mac browser):**
1. Geocode the preserve with Nominatim (`https://nominatim.openstreetmap.org/search?q=Autrey+Mill+Nature+Preserve+Johns+Creek+GA&format=json`). Send a descriptive `User-Agent` (for example `AutreyMillSentry/0.1 (student project, jeetusk08@gmail.com)`), one request per second max.
2. Pull trails, paths, bridges, boundary polygon, the stream (Sal's Creek), parking, buildings and picnic pavilions from the **Overpass API** inside a bounding box around the preserve (add a small margin). Save raw JSON to `data/raw/` and convert to bundled GeoJSON in `AutreyMillSentry/Resources/`: `trails.geojson`, `boundary.geojson`, `waterways.geojson`, `poi.geojson`.
3. **Verify against the official trail map.** Use the browser to open the preserve's website (autreymill.org, find the trail map page) and the City of Johns Creek park page, screenshot the official map, and compare trail names, loop shapes and points of interest against your GeoJSON. Fix gaps by hand-editing the GeoJSON, and list every discrepancy you could not resolve in `docs/MAP_NOTES.md`. If the official map is a PDF, you may read it for names and layout, but do not copy its artwork into the app.
4. Attribution is required and must appear in the About screen: "Map data © OpenStreetMap contributors (ODbL)" plus Apple Maps. Keep a `docs/LICENSES.md`.

**Map screen requirements:**
- Trails drawn as polylines (distinct, high-contrast, with trail names on tap), boundary outline, creek, parking and pavilions as annotations.
- User location dot, recenter button, "I'm at the preserve / you're X m away" hint.
- Report pins colored AND shaped by status (new, confirmed, treated, dismissed) so color-blind users can tell them apart. Tap a pin for a detail sheet (photo, species, confidence, date, status, patch size).
- Filters: species, status, date range.
- Works with no signal on the trail where possible: overlays are bundled and render without network. Say in `HANDOFF.md` what degrades offline (Apple basemap tiles).
- Camera region starts framed on the preserve and limits panning to a sensible area around it.

---

# FEATURE 2: THE SCANNER (the main thing; must be fully functional)

## What the user sees
Live camera preview with a framing guide. Real-time guidance text above the shutter (examples: "Move closer to the leaves", "Too dark, find some light", "Hold steady", "Plant in view, tap to capture"). A large shutter button (at least 44 x 44 pt, make it bigger). A photo-picker button for non-camera use. After capture, a result screen.

## Pipeline
1. **Live analysis** (about 4 frames per second, `AVCaptureVideoDataOutput` on a background queue, never block the main thread):
   - **Quality gates:** sharpness (variance of Laplacian via Accelerate or Core Image), exposure (mean luminance and clipped fraction), subject size (Vision attention-based saliency bounding box fills enough of the frame, and is not overflowing it), steadiness.
   - **Person check:** Vision face/human detection. If a person is prominent, do not capture and say "Please retake without people in the shot." (privacy).
   - **Live classification:** run the classifier on frames that pass the gates. Require agreement over a short window (for example 5 of the last 8 frames, same top class, mean probability above threshold) before showing a "locked on" state. This prevents flicker and is a good visual for the video.
2. **Capture:** on tap (or auto-capture when locked, user-toggleable), take a full-resolution photo, re-run the full gate and classification pass on the still, grab the best location fix. If horizontal accuracy is worse than about 30 m, wait a few seconds for a better fix and tell the user; allow saving with a "low accuracy" flag.
3. **Decision** (a pure function in `ScanDecision.swift`, fully unit-tested). Output is exactly one of:
   - `.confirmedInvasive(species, confidence)`: top class is a **Tier 1** invasive, calibrated probability above the confirm threshold, margin over the second class large enough.
   - `.possibleInvasive(candidates)`: plausible but not certain, or any Tier 2 species, or an unknown plant the user chooses to report. Goes to "Needs expert review". Never states a species as fact.
   - `.looksNative(name or "other plant", confidence)`: confidently a native look-alike or other plant. Friendly message ("Looks like native coral honeysuckle. No report needed."), with an option to send anyway.
   - `.rescan(reason)`: reasons are `blurry`, `tooDark`, `overexposed`, `tooFar`, `tooClose`, `noPlantFound`, `personInFrame`, `ambiguous`. Each has a specific, kind instruction and a tip for what to photograph (leaf close-up, leaf arrangement, flowers or berries, whole plant) based on the candidate species.
   Thresholds are initial values in `Config`; **tune them from held-out data** to hit a target precision for the "confirmed invasive" call (state the target and the achieved number in the model card).
4. **Result screen:** photo, result, calibrated confidence shown honestly (never a fake 99%), top 3 candidates, a one-line "why we think so" (what to look for on this plant), look-alike comparison link into Learn, a one-tap **patch size** picker (Few plants / Patch / Large stand), optional note, and **Save report**. Rescan results show only the instruction and a big "Try again" button.
5. **Duplicate handling:** if the same species was already reported within about 10 m in the last 7 days, offer "Add to existing report" instead of creating a new one.
6. **Geofence:** if the location is outside the preserve boundary plus a small buffer, warn "You're outside the preserve. Reports are saved as practice only and won't be ranked." (Debug builds get a simulated-location switch for development.)
7. Everything above works **offline** (no network needed to scan or save).

## Stored per report
`id`, `createdAt`, `latitude`, `longitude`, `horizontalAccuracy`, photo file path, `species`, `confidence`, top 3 probabilities, `modelVersion`, quality metrics, `patchSize`, `note` (never ask for a name), `status` (new / confirmed / treated / dismissed), `statusUpdatedAt`, `nearestTrailName`, `distanceToCreekMeters`, `priorityScore`, `sentAt`, `isPractice`, `needsExpertReview`.

---

# FEATURE 3: THE MODEL (train it, evaluate it honestly)

Folder `~/autrey-mill-sentry/model/`. Training is a Mac-native job.

## Classes: look for ALL invasive plants, tuned hardest on the common ones
Jeetu's instruction: the scanner should look for **all invasive species**, and he will test and tune it extra hard on the common ones. Be honest in the design: a small on-device model cannot identify every invasive reliably, so use **two tiers** and show the user which tier a result came from.

- **Tier 1, "tuned" (target 10 to 14 species, the ones Jeetu will field-test):** the invasives **documented at Autrey Mill** (from the preserve's own volunteer post, confirm with staff): **Chinese privet** (*Ligustrum sinense*), **Oregon grape holly** (*Mahonia bealei*), **Japanese honeysuckle** (*Lonicera japonica*), **Chinese wisteria** (*Wisteria sinensis*), **common periwinkle** (*Vinca minor*), plus the most common north Georgia invasives: English ivy (*Hedera helix*), Japanese stiltgrass (*Microstegium vimineum*), kudzu (*Pueraria montana*), nandina (*Nandina domestica*), and others that rank high on the GA-EPPC list and have plenty of Georgia photos. These get the most data, the most augmentation, per-class thresholds and the most testing. Results here can be `.confirmedInvasive`.
- **Tier 2, "broad coverage":** every other plant on the **Georgia Exotic Pest Plant Council (GA-EPPC) invasive list** that has enough usable iNaturalist images (set a minimum, for example 80 images, and document which species made it and which did not in `model/CLASSES.md`). These are trained as classes too, but a Tier 2 hit is **never** called confirmed. It always returns `.possibleInvasive` with the label "Possible invasive, needs expert review", because accuracy on rare classes will be lower.
- **Tier 3, "unknown invasive" safety net:** if the model sees a plant that looks unlike anything it knows, do not guess. Return `.possibleInvasive(unknown)` only if the user chooses "Report anyway" after seeing the result, and tag it `needsExpertReview` with the photo so staff can identify it. Honest framing in the UI: "We can't recognise this one. Want staff to take a look?"
- Also train **native look-alike classes** (for example coral honeysuckle *Lonicera sempervirens*, American wisteria *Wisteria frutescens*, native viburnums for privet, holly-leaf look-alikes for Mahonia) so Tier 1 species are not confused with natives, plus **`other_plant`** (diverse common Georgia understory plants) and **`not_plant`** (soil, bark, sky, hands, objects, blur).
- Verify every species' invasive status against GA-EPPC before including it. Do not include a native plant as an invasive.
- Propose the final tier lists with reasoning in `model/CLASSES.md` and proceed unless clearly wrong. Report accuracy **separately for Tier 1 and Tier 2** in the model card and in the app's accuracy card. If time or data runs short, trim Tier 2 first, never Tier 1 quality. Do not use the number of species supported as a bragging point, report measured accuracy.

## Data
- **Source:** iNaturalist API v1 (`https://api.inaturalist.org/v1/observations`), `quality_grade=research`, `photos=true`, **license filter to CC0, CC-BY, CC-BY-NC only**, prefer Georgia and the southeastern US (look up the Georgia `place_id` through `/v1/places/autocomplete`, do not guess), resolve taxon IDs through `/v1/taxa/autocomplete`. Respect rate limits (about 1 request per second, set a User-Agent), cache everything, download medium-size photos.
- Save `data/attribution.csv` (observation id, observer, license, URL) for every image used. Do not redistribute the images and do not commit them. Credits go in `docs/LICENSES.md` and the in-app credits list the data sources.
- Target a few hundred images per class, more for hard pairs. Include leaf, stem, flower, berry and whole-plant views, and in-situ forest-floor photos, not just clean close-ups.
- Optionally supplement with GBIF media if iNaturalist is thin for a class. Do not scrape sites that forbid it.

## Training
- Transfer learning from a small pretrained backbone (MobileNetV3-Large or EfficientNet-Lite via PyTorch or timm on **MPS**), input 224 or 256, strong augmentation (random crops, color jitter, blur, lighting, rotation) so it handles real phone photos. Create a conda or uv env for this; do not touch his `wdft` env.
- **Split by observer (and by observation), not by image**, so near-duplicate photos from one person do not leak into test. Fixed seeds. Class-balanced sampling or loss.
- **Calibrate** with temperature scaling on a validation split. Pick thresholds on validation, report on test.
- Convert with `coremltools` to a `.mlpackage` (FP16, include the classifier labels), keep the model small (target under about 25 MB), and verify the Core ML outputs match PyTorch on a batch of images before trusting it.
- Fallback if conversion or training gets stuck: Create ML image classifier (Xcode / `CreateML`), which is fine for this app.

## Evaluation (this becomes the technical-challenge story)
Write `model/eval/` JSON files and `docs/MODEL_CARD.md`: per-class precision and recall, confusion matrix, top-1 and top-3, calibration (ECE), precision at the confirm threshold and **coverage** (what fraction of true invasive photos the app confirms versus sends to "needs expert"), rejection behaviour on `not_plant` and blurry images, and the **hardest confusions** (for example privet vs native viburnum, Japanese vs coral honeysuckle) and Tier 1 vs Tier 2 results. State plainly that held-out accuracy comes from iNaturalist photos and will be lower in the field.
**Field validation:** include a small **Field Test mode** (Settings, off by default) where after a scan the tester can record the true label (checked by a person who knows the plant, such as staff or a trained volunteer). It exports a CSV so Jeetu can compute **field accuracy on 100+ photos at the preserve** and report the gap. Do not fill in field numbers until real data exists.
The app's About screen has a "How accurate is this?" card that reads real numbers from the bundled `model_card.json` and says "AI suggestion, not a guarantee. Staff make the final call."

---

# FEATURE 4: REPORTS AND THE RANGER VIEW

**My Reports tab:** list and detail of the user's reports with status, a **Send to preserve** action (package export described above), delete, and share.

**Ranger mode (Settings toggle "I'm preserve staff"; no real authentication is claimed or built, and the settings text says it is a demo role switch):**
- Prioritized work list and map of all reports, filters, status changes (new, confirmed, treated, dismissed) with timestamps.
- **Priority score**, documented on a "How we rank" screen and in `docs/RANKING.md`. Early-detection logic: rank higher when (a) the patch is small or isolated (patch size and few other reports within about 30 m), (b) it is near the creek (distance to the bundled waterway geometry), (c) the model confidence is high, (d) the report is recent and unaddressed, and (e) the species is an aggressive spreader (a small per-species weight with a source). Keep it a transparent weighted sum, unit-tested, with the weights in `Config`.
- **Work order export:** a one-page PDF of the top 10 priorities (species, coordinates, map thumbnail, photo, patch size, why it ranked). Treatment method is the staff's decision. The app must not recommend herbicides or doses, and must not tell visitors to remove plants themselves.
- When status becomes `treated`, schedule the local "Tell" notification (ask notification permission at that moment with a clear reason, not at launch).

---

# FEATURE 5: THE REST (keep it thin, high quality)

- **Learn:** one clear card per Tier 1 species (Tier 2 gets a simple name-and-link list): why it matters, how to recognise it (leaf arrangement, flower, berry, season), its **native look-alike with a side-by-side "tell them apart" tip**, and a source link. Use SF Symbols, illustrations you draw in SwiftUI, or CC-licensed photos with in-app attribution. No unlicensed images.
- **Visit:** address, phone, hours, admission note, directions button (opens Apple Maps), link to the preserve's events page (open with `SFSafariViewController`; do not scrape events). **Fetch hours and facts from the official site at build time and write the retrieval date next to them. Do not invent hours.** Known: 9770 Autrey Mill Road, Johns Creek, GA 30022, 678-366-3511, 46 acres, free to visit, groups of 10+ must reserve, run by the Autrey Mill Nature Preserve Association.
- **Onboarding:** 3 screens max. What it does, the safety promise, then the permission pre-prompts (camera, location) each with a plain-language reason before the system dialog appears.
- **Settings and Privacy:** privacy summary in plain English, **Delete all my data** button (wipes the database and photos), location-use explanation, Field Test mode, Ranger mode, About and credits (OpenStreetMap, iNaturalist observers by license, Apple frameworks, GA-EPPC, sources).
- **App name and icon:** working name "Autrey Mill Sentry" (home screen display name "Mill Sentry"). Make an original icon (a leaf with a watchful eye or a pin, no preserve logo). Do not use the preserve's logo, name styling or photos unless staff give permission (list it as a question for Jeetu).

---

# PRIVACY, LEGAL AND SAFETY (build it in, do not bolt it on)

I cannot promise legal compliance for every possible situation, and this is a student app, so build to the standards below, document what was done in `docs/PRIVACY.md`, and list anything that needs a human decision in `HANDOFF.md`.

- **Data minimisation:** no accounts, no email, no name, no phone number, no advertising ID, no analytics, no third-party SDKs, no tracking. Data stays on the device until the user explicitly sends a report.
- **Permissions:** camera and location **When In Use only**. Write honest `NSCameraUsageDescription` and `NSLocationWhenInUseUsageDescription` strings. No background location, no always-on tracking. Ask at the moment of need, with a pre-prompt explaining why. Everything except scanning works if location is denied (the scanner explains that reports need a location to be useful and lets the user save as practice).
- **Privacy manifest:** include `PrivacyInfo.xcprivacy` declaring no tracking and any required-reason APIs actually used (for example file timestamp or UserDefaults), checked against Apple's current list. Follow Apple's App Review Guidelines section 5.1 (privacy) as the standard even though we are not submitting to the App Store.
- **People and minors:** the app refuses captures with a prominent person and warns "don't photograph people, especially children". Strip EXIF GPS and device metadata from stored and exported photos. Notes are free text, so add a gentle "don't include names or personal info" hint. The app is for general audiences and collects no personal information, which keeps it clear of children's-data collection concerns.
- **Location precision:** coordinates are stored precisely (staff need them) and are only shared when the user taps Send. Provide an option to round coordinates to about 100 m on export for anything meant to be public.
- **Safety copy** (onboarding and scan screen): stay on marked trails, do not touch or pick plants (poison ivy, brambles, ticks), watch your footing near the creek, supervise children, follow posted preserve rules, and "report it, do not remove it". Do not encourage entering closed areas or sensitive habitat. Do not record rare or protected native species (for example the preserve's native pink lady's slipper): they are not in the classifier, and if one is photographed the app shows only "other plant".
- **AI honesty:** every result carries "AI suggestion, not a guarantee." The model can be wrong. Low confidence never produces a species claim.
- **Content rights:** respect OpenStreetMap (ODbL attribution), iNaturalist per-photo licenses (CC0, CC-BY, CC-BY-NC only, attribution recorded), and Apple's SF Symbols terms. No copyrighted photos, no preserve logo without permission.
- **Terms/consent:** no account, so no terms to accept. A one-screen "How your data is used" is shown in onboarding and always available.

---

# APPLE DESIGN RULES (from https://developer.apple.com/design/tips/ and the HIG)

Treat these as acceptance criteria. Use native SwiftUI components so the app picks up the current system look automatically, and do not fight the system with heavy custom chrome. Aim for a bold, graphic, memorable style (strong colour, confident type, nothing that reads as a generic template), still within these rules:

- **Formatting content:** layout fits every iPhone screen size; primary content visible without zooming or horizontal scrolling. Respect safe areas. Test on the smallest and largest simulators.
- **Touch controls:** use controls designed for touch (standard buttons, sheets, swipe actions, menus).
- **Hit targets:** every tappable control is **at least 44 x 44 pt**, including map filters, pins, close buttons and the shutter.
- **Text size:** nothing smaller than **11 pt**; use Dynamic Type text styles so it scales; no truncation at the largest accessibility sizes on key screens.
- **Contrast:** strong contrast between text and background in light and dark mode, including text over camera and map (use materials or scrims). Meet at least WCAG AA.
- **Spacing:** no overlapping text; generous line height and padding.
- **High resolution:** use vector assets or provide `@2x`/`@3x`; app icon at 1024 px in the asset catalog; no blurry images.
- **Distortion:** always display images at their intended aspect ratio (`scaledToFit` or clipped `scaledToFill`).
- **Organization:** controls sit next to the content they change; clear navigation hierarchy; one primary action per screen.
- **Alignment:** align text, images and buttons consistently to show relationships.
- **Also:** full **VoiceOver** labels and hints (map pins included), dark mode, Reduce Motion respected, haptic feedback on lock-on and save, color is never the only signal, sensible empty states, and clear loading and error states. Add a `docs/DESIGN_CHECKLIST.md` that ticks each rule above with how it was verified (screenshots in Simulator at small and large sizes, Accessibility Inspector).

---

# RUBRIC MAP (build so the video can point at these)

Per official CAC instructions the video is **3 minutes max** and judges also read short answers. Build each feature so there is a clear on-screen moment for it.

| Rubric theme | What judges look for | Feature and demo moment |
|---|---|---|
| Real problem and local impact | A concrete user and problem | Invasives at Autrey Mill (cite the documented species), staff reaction, a real map with real pins from Jeetu's field walk. Show actual pilot counts only if they exist. |
| Creativity and originality | Not just another field guide | The closed loop (Spot, Verify, Act, Tell) and the early-detection priority rank, not just an ID app |
| Functionality | It actually works, live | Live scan on the phone: lock-on, capture, result, saved pin appears on the map. Then a blurry or too-far shot triggering a specific rescan prompt. |
| Technical difficulty | Something hard, solved well | On-device Core ML trained and calibrated by Jeetu, observer-level splits, quality gates, the confirm/needs-expert/native/rescan decision, honest accuracy gap |
| Design and user experience | Thought given to design | Clean flow, Apple HIG rules, accessibility, onboarding, dark mode, shape-plus-color status pins |
| Responsible design | Privacy, safety, ethics | When-In-Use location, no accounts, no people in photos, delete-all-data, "AI suggestion, not a guarantee" |
| Staff value | Does someone actually use the output | Ranger view, ranked work order PDF, status change, notification to the reporter |

Also produce `docs/DEMO_SCRIPT.md` (a second-by-second 2:45 outline that hits every row above, including what to film on site, what to screen-record from the phone, and what to say), `docs/SHORT_ANSWERS.md` (drafts for "what inspired you" and "technical challenge and how you solved it", in Jeetu's voice: short declarative sentences, contractions, no dashes of any kind, no semicolons, never sounding AI-written, only claims that are true), and `docs/FEATURE_LIST.md`.

---

# BUILD PLAN AND CHECKPOINTS

Always keep a **demoable build** on the device. Commit at the end of each step (local git).

1. **Step 0:** environment check, project exists, a Hello World runs on his phone. (Oct 12)
2. **Step 1:** data fetch (map GeoJSON + iNaturalist dataset download) in the background, app shell with tabs, onboarding and settings, `MockClassifier`. Start the data download early because it is slow. (Oct 12 to 13)
3. **Step 2:** map screen with real preserve data, then train the model while building the scanner UI against the mock. Gate scanner pipeline, decision logic and unit tests. (Oct 13 to 15)
4. **Step 3:** swap in the real model, tune thresholds, **scanner works end to end on the phone. Checkpoint Oct 16 so Jeetu can start field photos that weekend.** (Oct 15 to 16)
5. **Step 4:** reports, duplicates, Ranger mode, ranking, work order PDF, notification, Learn, Visit, Privacy screens. (Oct 16 to 20)
6. **Step 5:** accessibility pass, design checklist, field test mode, full unit and UI tests, model card from real evals, docs and demo script. (Oct 20 to 22)
7. **Step 6:** final signed build installed Oct 22 or later, README, clean repo for submission, final `HANDOFF.md`. (Oct 22 to 24)

Jeetu's other deadlines compete for the same Mac and time: Learn2Design report Oct 15, QuantiPhy Oct 23, Stanford PAIE and the Observability paper Oct 30. Do not let this grow. If time gets tight, **cut in this order:** Tier 2 species, Learn photos, work order PDF polish, Visit extras, then Field Test mode. Never cut: map, scanner with rescan logic, report saving, Ranger priority list, privacy basics.

---

# DONE MEANS

- App installs and runs on Jeetu's iPhone, scanner works live and from the photo picker, offline.
- Map shows real preserve trails and boundary, verified against the official map, and report pins.
- Scanner returns one of four outcomes with correct behavior, rescans with specific reasons, saves reports with all fields, and handles duplicates and out-of-preserve locations.
- Ranger mode lists reports by a documented, tested priority score, and exports the work order.
- Real model with a real model card; no unverified numbers anywhere.
- Privacy and safety items above all implemented and listed in `docs/PRIVACY.md`.
- All Apple design rules ticked in `docs/DESIGN_CHECKLIST.md`.
- Unit tests pass. A clean `xcodebuild` build has no warnings that matter.
- `README.md`, `HANDOFF.md`, `docs/DEMO_SCRIPT.md`, `docs/SHORT_ANSWERS.md`, `docs/FEATURE_LIST.md`, `docs/SOURCES.md`, `docs/LICENSES.md` exist.

# ONLY JEETU CAN DO THESE (stop and tell him when you reach them)
1. Create the empty Xcode project and pick his personal signing team (Apple ID sign-in).
2. Enable Developer Mode on the phone, trust the developer certificate, tap all permission prompts.
3. Get the preserve's contact email for `Config.rangerEmail` and ask staff the open questions: full list of 14 documented invasives, whether to use their logo, any rules for volunteers and reports, and whether they want to try the Ranger view.
4. Take and label the field photos at the preserve (with a person who knows the plants) and run Field Test mode.
5. Record the video (3 minutes max), upload to YouTube or Vimeo, register for CAC and confirm his congressional district and parent consent, and submit the code, video and answers before **Oct 26, 12:00 pm ET**.
6. Decide how to hand over source code for CAC (repo visibility is his call).

# REPORT BACK
At each checkpoint reply with: what works, what you verified (command output, screenshots), the real eval numbers so far, what is blocked on Jeetu, and the next step. Short and plain.
