# HANDOFF: Autrey Mill Sentry

Updated 2026-10-13 (02:40). Project: `~/autrey-mill-sentry` (local git only, no remote). Deadline: CAC submission **Mon Oct 26, 2026, 12:00 pm ET**. Checkpoints: scanner on the phone **Oct 16**, feature complete Oct 20, polish and video Oct 24.

## Status
| Area | State |
|---|---|
| Step 0 environment | Xcode 27.0 installed and licensed on 12 Oct 23:00 (use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; `xcode-select` still points at the CLT). iOS simulator runtime downloading. Earlier state: **Xcode was not installed** (only Command Line Tools at `/Library/Developer/CommandLineTools`); no `.xcodeproj` existed, no iPhone visible on USB. Swift 6.3.3 CLT, macOS 26.6.2, Python 3.14 (miniforge) and 3.12 (`~/.local/bin`), uv, Node 24, 395 GB free. QuantiPhy (`vmc.py` x3) is using all CPU, so training runs with `nice` and `VECLIB_MAXIMUM_THREADS=1`. |
| Map data | Done. OSM via Overpass, clipped to the park polygon: 36 trail ways (Warsaw Trail, Mill Race, Perimeter Trail East, Forest Trail North, Forest Pass, Wetland Pass, Spur Trail + unnamed), boundary, Sal's Creek + pond, 23 POIs. Compared with the official 2024 map; discrepancies in `docs/MAP_NOTES.md`. |
| Dataset | Done: 33,564 licensed iNaturalist photos across 114 classes (14 Tier 1 + 14 native + 84 Tier 2 + other_plant + not_plant), 4.5 GB in `data/images/` (not committed), attribution in `data/attribution.csv` and observer credits appended to `docs/LICENSES.md`. Re-run: `~/miniforge3/bin/python3 -I tools/fetch_inat.py download`. |
| App code | **Compiles with Xcode 27.0, 0 errors, 0 warnings. On the iPhone 17 simulator (iOS 27.0): 48/48 unit tests pass, both happy-path UI tests pass (sample photo -> confirmed privet -> save -> listed in Reports; not-a-plant -> specific rescan instruction).** Screenshot walkthrough captured on iPhone 17 (`docs/screenshots/iphone-17-light/`, 15 screens, all render correctly); Also captured on iPhone 17e, iPhone 18 Pro Max dark and iPhone 17 at the largest accessibility size (all fit). XCTest accessibility audit run: real contrast/Dynamic Type/hit-area findings fixed (commit "Accessibility fixes"); re-verification chain in `data/logs/sim_chain2.log`. `docs/DESIGN_CHECKLIST.md` filled in. **Animations added 13 Oct (Jeetu's request)**: launch sequence (`App/LaunchOverlay.swift`, `Shared/Motion.swift`) and motion across scan, result, map, lists, onboarding, learn, visit; all Reduce Motion aware; skipped under `-uiTesting` unless `-showLaunch`. Launch verified frame by frame (`docs/screenshots/launch/`, `tools/launch_frames.sh`): forest-green system launch screen (`SupportingFiles/Info.plist`, merged with the generated plist), leaf + eye, title, lift. Walkthrough screenshots re-pass after the animation work. Unit tests 53/53. Not yet run on a phone: needs the signing team and a connected iPhone. Pure logic (decision, lock-on, ranking, geometry, duplicates, CSV) type-checks and runs on macOS with the CLT. All screens, services, camera pipeline, exports, Ranger mode, Learn, Visit, onboarding, settings, privacy manifest, app icon, unit tests and UI tests exist. `AutreyMillSentry.xcodeproj` was hand-written (Xcode 16 synchronized-folder format) with a shared scheme. |
| Model v2 (bundled) | EfficientNet-B0 at 256 px, 20 epochs on MPS (~35 min), observer-level split 26,199 / 4,131 / 3,234 images (6,430 / 702 / 827 observers). **Test top-1 85.6%, top-3 93.4%; Tier 1 top-1 88.7%, Tier 2 85.5%, natives 90.3%.** Temperature 0.796, test ECE 0.016. Confirm target 97% precision on validation: global threshold 0.82 (+14 per-class, floor 0.60), margin 0.30: **test precision 95.9%, coverage 78.8%**, natives/others wrongly confirmed 0.8%, not_plant rejected 74.2%. Core ML FP16 export 8.0 MB, top-1 agreement with PyTorch 40/40. Files: `model/eval/v2_eval.json`, `docs/MODEL_CARD.md`, `Resources/model_card.json`, `Resources/thresholds.json`, `Resources/InvasiveClassifier.mlpackage`. v1 (MobileNetV3-Large 224, 14 epochs) kept in `model/eval/v1_eval.json`: test top-1 81.2%, precision 96.4% at coverage 72.3%; v2 beat it on every group, so v2 ships. |
| Docs | README, CLASSES, MAP_NOTES, SOURCES, RANKING, PRIVACY, LICENSES written. MODEL_CARD comes from the real eval. DESIGN_CHECKLIST, DEMO_SCRIPT, SHORT_ANSWERS, FEATURE_LIST: Step 5. |

## Blocked on Jeetu (do these, in order)
1. **Install Xcode** from the Mac App Store (free, large download), open it once and accept the license, let it install the iOS platform. Then either run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` or just tell Claude; Claude can use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` without sudo.
2. Open `~/autrey-mill-sentry/AutreyMillSentry.xcodeproj`, click the AutreyMillSentry target > Signing & Capabilities > **Team: your personal team** (Apple ID sign-in). If Xcode refuses the hand-written project file, say so: the fallback is XcodeGen (`project.yml` can be written in a minute).
3. Phone: Settings > Privacy & Security > **Developer Mode on**; after the first install, Settings > General > VPN & Device Management > trust the certificate. Tell Claude **which iPhone and iOS version**.
4. Ask preserve staff: the contact email for `Config.rangerEmail` (the site lists info@autreymill.org as a general contact; do not put it in the app until they say it is right), the current list of invasives (the 2012 post lists 14), current trail names (Millers' Trail, Wildflower Trail, River Trail, Forest Loop are not in OSM), whether trail hours are 8 to 8 or 8 to 9, logo permission (not used now), rules for volunteer reports, and whether they want to try the Ranger view.
5. Later: field photos with someone who knows the plants (Field Test mode), the video, CAC registration (district + parent consent), source-code handover decision, final install on **Oct 22 or later** (free-ID builds expire after 7 days; do not reinstall mid-recording).

## What Claude does next (no input needed)
1. (done) v2 chosen and bundled.
2. As soon as Xcode exists: build for the Simulator, fix compile errors, run unit and UI tests, screenshot small and large simulators for the design checklist.
3. Then build for the phone (after the team is set): `xcodebuild -scheme AutreyMillSentry -destination 'id=<udid>' build` and install with `xcrun devicectl device install app`.
4. Steps 4 to 6 per the plan: design checklist, demo script, short answers, feature list, README polish, clean repo.

## How to build and run
See README. Simulator: Scan tab > photo button. Debug Settings has "Simulate location at the preserve". UI tests use `-uiTesting -skipOnboarding -mockScan confirmed -simulateLocation` and a bundled drawn sample leaf.

## Rules kept
No money spent. No secrets in the repo (`.gitignore` covers data, models, signing). Training images never committed. No number in the app or docs that did not come from `model/eval/*.json` (the About card shows "no evaluation yet" until then). Preserve not described as endorsing anything. Remote not created.

## Known gaps and risks
- Hand-written `project.pbxproj`: should open in Xcode 16/26; untested until Xcode is installed.
- UI code is unverified by a compiler; expect a round of small fixes on first build.
- Trail names: OSM names differ from the preserve's map (see MAP_NOTES).
- Offline: overlays and pins work offline; Apple basemap tiles need a prior view or signal.
- `Config.rangerEmail` is `TODO_RANGER_EMAIL`; Send falls back to the share sheet.
