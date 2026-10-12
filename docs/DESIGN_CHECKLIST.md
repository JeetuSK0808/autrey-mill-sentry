# Apple design checklist

Each rule from https://developer.apple.com/design/tips/ and the HIG, with how it was verified. "Pending" means the code is written to the rule but not yet checked on a simulator or device (needs Xcode).

| Rule | How the app meets it | Verified |
|---|---|---|
| Formatting content: fits every iPhone size, no zoom or horizontal scroll, safe areas respected | Native stacks, lists and ScrollViews; camera preview uses `ignoresSafeArea` only on the bottom edge; controls inside safe areas | Pending: iPhone SE (3rd gen) and iPhone 16 Pro Max simulators, screenshots in `docs/screenshots/` |
| Touch controls | Standard buttons, segmented picker, toggles, sheets, swipe actions, menus; no custom gesture-only controls | Pending |
| Hit targets at least 44 x 44 pt | Shutter 84 pt; picker and auto buttons 64 pt; map pins, trail markers, POIs and close buttons wrapped in `.frame(minWidth: 44, minHeight: 44)`; status buttons `minHeight: 44` | Pending: Accessibility Inspector audit |
| Text size at least 11 pt, Dynamic Type | Only text styles (`.caption2` is 11 pt at default size); no fixed point sizes in body text; `TextField` with axis vertical | Pending: largest accessibility size on Scan, Result, Map, Ranger |
| Contrast, light and dark mode, text over camera and map | Guidance pill and controls sit on dark scrims and materials over the camera; map hints on `.thinMaterial`; system colours elsewhere; status colours paired with shapes | Pending: both appearances, WCAG AA spot check with the inspector |
| Spacing, no overlapping text | Generous padding (16) in cards; no absolute layout except the framing guide, which is decorative | Pending |
| High resolution assets | SF Symbols and SwiftUI-drawn shapes only; app icon 1024 px PNG in the asset catalog | Done (asset catalog) |
| Image distortion | `CGImageView` uses `scaledToFill` with `.clipped()` or `scaledToFit`; thumbnails keep aspect | Done in code |
| Organization: controls next to content, one primary action per screen | Save on the result, Send in Reports, shutter on Scan, status buttons on the report | Done in code |
| Alignment | Leading-aligned text columns, consistent card layout | Pending |
| VoiceOver labels and hints | Labels on shutter, picker, pins ("Chinese privet, new report"), trail markers, guidance pill (`updatesFrequently`), status badges; `accessibilityElement(children: .combine)` on rows | Pending: VoiceOver walkthrough |
| Dark mode | System colours and materials; accent colour has a dark variant | Pending |
| Reduce Motion | Framing-guide animation disabled when Reduce Motion is on; no other custom animation | Done in code |
| Haptics | `.sensoryFeedback` on lock-on and save (system respects the user's haptics setting; app toggle too) | Pending on device |
| Colour never the only signal | Status = shape + colour + label; tier badges carry text | Done in code |
| Empty, loading and error states | `ContentUnavailableView` for no reports; capture and identify overlays; alerts for camera and export errors; camera-denied screen with a Settings link | Pending |
