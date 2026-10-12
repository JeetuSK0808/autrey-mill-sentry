# HANDOFF: Autrey Mill Sentry

Updated 2026-10-12 (evening). Project: `~/autrey-mill-sentry` (local git only, no remote). Deadline: CAC submission **Mon Oct 26, 2026, 12:00 pm ET**. Checkpoints: scanner on the phone **Oct 16**, feature complete Oct 20, polish and video Oct 24.

## Status
| Area | State |
|---|---|
| Step 0 environment | Done, with one blocker: **Xcode is not installed** (only Command Line Tools at `/Library/Developer/CommandLineTools`); no `.xcodeproj` existed, no iPhone visible on USB. Swift 6.3.3 CLT, macOS 26.6.2, Python 3.14 (miniforge) and 3.12 (`~/.local/bin`), uv, Node 24, 395 GB free. QuantiPhy (`vmc.py` x3) is using all CPU, so training runs with `nice` and `VECLIB_MAXIMUM_THREADS=1`. |
| Map data | Done. OSM via Overpass, clipped to the park polygon: 36 trail ways (Warsaw Trail, Mill Race, Perimeter Trail East, Forest Trail North, Forest Pass, Wetland Pass, Spur Trail + unnamed), boundary, Sal's Creek + pond, 23 POIs. Compared with the official 2024 map; discrepancies in `docs/MAP_NOTES.md`. |
| Dataset | Downloading in the background (`data/logs/fetch_inat.log`): 14 Tier 1 + 14 native + 84 Tier 2 + other_plant + not_plant, licensed iNaturalist photos, attribution in `data/attribution.csv`. Restartable: `~/miniforge3/bin/python3 -I tools/fetch_inat.py download`. |
| App code | Written (not yet compiled: needs Xcode). Pure logic (decision, lock-on, ranking, geometry, duplicates, CSV) type-checks and runs on macOS with the CLT. All screens, services, camera pipeline, exports, Ranger mode, Learn, Visit, onboarding, settings, privacy manifest, app icon, unit tests and UI tests exist. `AutreyMillSentry.xcodeproj` was hand-written (Xcode 16 synchronized-folder format) with a shared scheme. |
| Model pipeline | `model/train.py`, `evaluate.py`, `export_coreml.py` smoke-tested end to end on the partial dataset (1 epoch, 20 classes): train on MPS, temperature scaling, threshold tuning, eval JSON, model card, Core ML FP16 export (8.6 MB) and a PyTorch-vs-Core ML check. Smoke artifacts were deleted; nothing from them is shown anywhere. Real training starts when the download finishes. |
| Docs | README, CLASSES, MAP_NOTES, SOURCES, RANKING, PRIVACY, LICENSES written. MODEL_CARD comes from the real eval. DESIGN_CHECKLIST, DEMO_SCRIPT, SHORT_ANSWERS, FEATURE_LIST: Step 5. |

## Blocked on Jeetu (do these, in order)
1. **Install Xcode** from the Mac App Store (free, large download), open it once and accept the license, let it install the iOS platform. Then either run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` or just tell Claude; Claude can use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` without sudo.
2. Open `~/autrey-mill-sentry/AutreyMillSentry.xcodeproj`, click the AutreyMillSentry target > Signing & Capabilities > **Team: your personal team** (Apple ID sign-in). If Xcode refuses the hand-written project file, say so: the fallback is XcodeGen (`project.yml` can be written in a minute).
3. Phone: Settings > Privacy & Security > **Developer Mode on**; after the first install, Settings > General > VPN & Device Management > trust the certificate. Tell Claude **which iPhone and iOS version**.
4. Ask preserve staff: the contact email for `Config.rangerEmail` (the site lists info@autreymill.org as a general contact; do not put it in the app until they say it is right), the current list of invasives (the 2012 post lists 14), current trail names (Millers' Trail, Wildflower Trail, River Trail, Forest Loop are not in OSM), whether trail hours are 8 to 8 or 8 to 9, logo permission (not used now), rules for volunteer reports, and whether they want to try the Ranger view.
5. Later: field photos with someone who knows the plants (Field Test mode), the video, CAC registration (district + parent consent), source-code handover decision, final install on **Oct 22 or later** (free-ID builds expire after 7 days; do not reinstall mid-recording).

## What Claude does next (no input needed)
1. Wait for the dataset, then train (`model/train.py --version v1`, about 14 epochs), evaluate, export, write the model card, bundle the `.mlpackage` and `thresholds.json`.
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
