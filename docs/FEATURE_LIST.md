# Feature list

Status key: built = code exists; verified = seen working on device or Simulator; (date) = when verified.

## Scanner (Spot, Verify)
- Live camera preview with framing guide and real-time guidance text (built)
- Quality gates per frame: sharpness (variance of Laplacian), exposure (mean luminance, clipped fraction), subject size via Vision saliency, steadiness via frame difference (built)
- Person check with Vision human and face detection; capture refused with a privacy message (built)
- Live classification at about 4 fps on a background queue, lock-on after 5 of 8 agreeing frames with mean probability above threshold, haptic on lock (built)
- Shutter 84 pt, photo-picker input for Simulator, judges and tests, optional auto-capture when locked (built)
- Still re-analysis after capture, best location fix with a wait for 30 m accuracy and a low-accuracy flag (built)
- Decision logic with exactly four outcomes: confirmed invasive, possible invasive (needs expert review), looks native, rescan with one of eight specific reasons and a species-specific photo tip (built, unit tested)
- Tier 2 species never confirmed; Tier 3 "report anyway" safety net for unknown plants (built)
- Result screen: photo, calibrated confidence bar, top 3, why we think so, look-alike link into Learn, patch size picker, note, save (built)
- Duplicate handling: same species within 10 m in 7 days offers "Add to existing report" (built, unit tested)
- Geofence: outside the boundary plus 60 m is saved as practice and not ranked (built, unit tested against the real boundary)
- Works offline (model, overlays and store are on the device) (built)

## Map (Act)
- Bundled OpenStreetMap trails, boundary, Sal's Creek and pond, parking, pavilions, benches, toilets, gate (built)
- Trail names on tap, user location dot, recenter, "you're at the preserve / X m away" hint, camera bounds around the preserve (built)
- Report pins shaped and coloured by status with VoiceOver labels; detail sheet (built)
- Filters by species, status, date range (built)

## Reports and Ranger (Act, Tell)
- My Reports list, detail, delete, share (built)
- Send to preserve: PDF summary + CSV + EXIF-stripped photos via Mail (when an address is set) or the share sheet; `ReportSyncing` protocol with `LocalOnlySync` (built)
- Ranger mode (demo role switch): prioritized work list, status changes with timestamps, map of all reports, filters (built)
- Transparent priority score with "How we rank" screen and `docs/RANKING.md` (built, unit tested)
- Work order PDF of the top 10 with map thumbnails and photos (built)
- Local "treated" notification to the reporter, permission asked at that moment (built)

## Learn, Visit, Onboarding, Settings
- Learn cards for 14 tuned species and 14 native look-alikes with tell-them-apart tips and sources; Tier 2 list with links (built)
- Visit: address, phone, hours with retrieval date, directions in Apple Maps, events page in SFSafariViewController, safety copy (built)
- Onboarding, 3 screens, with permission pre-prompts (built)
- Settings: Ranger mode, Field Test mode with CSV export, auto-capture, haptics, coordinate rounding on export, delete all data, privacy summary, About with the accuracy card read from `model_card.json` (built)
- Privacy manifest, no analytics, no third-party code (built)

## Model
- iNaturalist dataset builder with licence filter and attribution (built, ran)
- Training (MobileNetV3-Large, MPS, observer-level split, balanced sampling, augmentation), temperature calibration, threshold tuning, evaluation JSON, model card, Core ML export with a PyTorch comparison (built, smoke-tested)
