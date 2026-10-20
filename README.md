# Autrey Mill Sentry

**Every visitor becomes a sentry for the preserve.** A native iOS app (Swift, SwiftUI, SwiftData, MapKit, Vision, Core ML) that lets visitors of Autrey Mill Nature Preserve & Heritage Center (Johns Creek, Georgia) spot invasive plants with the phone camera, verifies the shot on the device, saves a located report, and gives preserve staff a ranked early-detection work list. A student project by Jeetu SK for the 2026 Congressional App Challenge. Built for the preserve; not an official preserve app.

## The loop: Spot, Verify, Act, Tell
1. **Spot.** Live camera with framing guidance ("Move closer to the leaves", "Too dark, find some light", "Hold steady"). An on-device Core ML classifier runs on frames that pass sharpness, exposure, subject-size and person checks, and must agree over several frames before it says "locked on".
2. **Verify.** Exactly one of four outcomes: confirmed invasive (Tier 1 species above a calibrated, validation-tuned threshold), possible invasive (needs expert review), looks native (no report needed), or rescan with a specific reason. Low confidence never names a species as fact.
3. **Act.** Reports land on a real map of the preserve (OpenStreetMap trails, boundary, Sal's Creek) and, in Ranger mode, on a prioritized work list with a transparent score (small isolated patches near the creek first) and a one-page work order PDF.
4. **Tell.** When staff mark a report treated, the reporter gets a notification on the device.

## Privacy by design
No accounts, no analytics, no third-party SDKs. Camera and When-In-Use location only. Photos are stored without EXIF. Shots with people are refused. Nothing leaves the phone until the user taps Send. "AI suggestion, not a guarantee" on every result. See `docs/PRIVACY.md`.

## Build and run
Requirements: Xcode 16 or newer (iOS 17 SDK), a free Apple ID for device signing, iPhone with iOS 17+.

1. Open `AutreyMillSentry.xcodeproj`, select the `AutreyMillSentry` target, set **Signing & Capabilities > Team** to your personal team.
2. Run on a device (the camera needs one). The Simulator works for everything else; use the photo-picker button on the Scan tab.
3. Tests: Product > Test, or `xcodebuild test -scheme AutreyMillSentry -destination 'platform=iOS Simulator,name=iPhone 16'`.

Debug builds have a "Simulate location at the preserve" switch in Settings. Launch arguments for automation: `-uiTesting -skipOnboarding -mockScan confirmed|possible|native|ambiguous|notplant|tier2 -simulateLocation`.

## Model
`model/` holds the training pipeline (PyTorch on Apple MPS, EfficientNet-B0 at 256 px, observer-level split, trail-camera augmentation, temperature calibration, threshold tuning, Core ML export) and `model/field_eval.py`, which measures the scanner's decisions on held-out photos degraded like trail shots (dusk, backlight, blur, far subject). `dashboard/` is the preserve staff site (Next.js on Vercel): reports sent from the app land there, ranked and on a map, and a status change comes back to the visitor's phone. `model/CLASSES.md` explains the species tiers; `docs/MODEL_CARD.md` holds the measured results. The app shows only numbers produced by `model/evaluate.py`. Training images are iNaturalist CC-licensed photos and are not included in the repository.

## Repository layout
- `AutreyMillSentry/` app source (App, Scanner, Map, Reports, Ranger, Learn, Visit, Onboarding, Settings, Services, Shared, Resources)
- `AutreyMillSentryTests/`, `AutreyMillSentryUITests/`
- `model/` training, evaluation, export; `tools/` data fetch scripts
- `docs/` sources, licenses, map notes, ranking, privacy, model card, design checklist, demo script, short answers
- `HANDOFF.md` status and next steps

## Credits
Map data © OpenStreetMap contributors (ODbL). Training photos from iNaturalist observers under CC0 / CC BY / CC BY-NC (see `docs/LICENSES.md`). Species status from the Georgia Invasive Species Council; aggressiveness weights from the Georgia Forestry Commission Dirty Dozen list.
