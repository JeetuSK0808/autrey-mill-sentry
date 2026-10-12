# Privacy, legal and safety: what was built

Standard followed: Apple App Review Guidelines 5.1 (privacy) and the Human Interface Guidelines, even though this build is installed with a free Apple ID and not submitted to the App Store. Items needing a human decision are listed at the end and in `HANDOFF.md`.

## Data minimisation
- No accounts, no name, email or phone number, no advertising identifier, no analytics, no third-party SDKs, no tracking. Only first-party Apple frameworks plus the bundled Core ML model.
- A report stores: id, timestamps, coordinates and accuracy, a JPEG photo file, species label and probabilities, model version, quality metrics, patch size, an optional free-text note, status, nearest trail, distance to the creek, priority score, flags. Nothing identifies the reporter.
- Data stays on the device (SwiftData store plus `Application Support/Photos/`) until the user taps **Send to preserve**, which opens Mail or the share sheet with a package they can inspect (PDF, CSV, photos).

## Permissions (asked at the moment of need, with a pre-prompt)
- **Camera**, `NSCameraUsageDescription`: "The camera is used to scan plants live. You can also choose a saved photo instead."
- **Location, When In Use only**, `NSLocationWhenInUseUsageDescription`: "Your location, only while the app is open, pins reports on the preserve map so staff can find the plant. No background tracking." No background modes, no Always authorization anywhere in the code.
- **Notifications**: requested only when staff mark a report treated (the "Tell" step), never at launch.
- Everything except live scanning works with camera or location denied: the photo picker still scans, and reports without a location are saved as practice with an explanation.

## Privacy manifest
`PrivacyInfo.xcprivacy` declares no tracking, no tracking domains, no collected data types, and the required-reason APIs actually used: UserDefaults (CA92.1, app's own settings) and file timestamps (C617.1, the app's own files).

## People and minors
- Live frames and stills run Vision human and face detection; a prominent person blocks capture with "Please retake without people in the shot. Do not photograph people, especially children."
- Stored and exported photos are re-encoded from pixels with no EXIF, GPS or device metadata.
- The note field carries the hint "no names or personal info, please".
- The app is for general audiences and collects no personal information; this keeps it clear of children's-data collection concerns, and the safety copy tells adults to supervise children.

## Location precision
Coordinates are stored precisely because staff need them. They leave the phone only when the user sends a report. Settings offers "Round coordinates to about 100 m on export" (3 decimals, roughly 100 m) for anything meant to be public.

## Safety copy (onboarding, scan screen, Visit)
Stay on marked trails; do not touch or pick plants (poison ivy, brambles, ticks); watch your footing near the creek; supervise children and keep people out of photos; report it, do not remove it; do not enter closed areas or sensitive habitat. Rare or protected natives (such as the preserve's pink lady's slipper orchids) are not classes; they come out as "other plant" and are never mapped as targets.

## AI honesty
Every result screen, the About card and the exports carry "AI suggestion, not a guarantee. Staff make the final call." Low confidence never produces a species claim; Tier 2 results are never shown as confirmed; the accuracy card shows only numbers produced by `model/evaluate.py` from a held-out test set, and says field accuracy is unmeasured until it is measured.

## Content rights
OpenStreetMap data under ODbL with attribution in About; iNaturalist photos used for training only under CC0, CC BY, CC BY-NC with per-photo attribution recorded (none redistributed in the app); SF Symbols under Apple's terms; no preserve logo, name styling or photos are used.

## Needs a human decision (Jeetu or staff)
- Whether the preserve wants its name on the app beyond "built for Autrey Mill Nature Preserve", and whether the logo may be used (currently not used).
- The address for `Config.rangerEmail` and who at the preserve receives report packages.
- Whether reports should ever be published (if so, use the rounding option).
- Retention: there is no automatic deletion; the user deletes reports individually or all at once in Settings.
