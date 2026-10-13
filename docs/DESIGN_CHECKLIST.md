# Apple design checklist

Rules from https://developer.apple.com/design/tips/ and the HIG, with how each was verified. Evidence: `docs/screenshots/` (iPhone 17 light, iPhone 17e light, iPhone 18 Pro Max dark, iPhone 17 at the largest accessibility text size, all captured by `ScreenshotUITests` on the iOS 27.0 simulator on 13 Oct 2026) and `docs/accessibility_audit.txt` (XCTest `performAccessibilityAudit`, all audit types, on nine screens).

| Rule | How the app meets it | Verified |
|---|---|---|
| Formatting content: fits every iPhone size, no zoom or horizontal scroll, safe areas respected | Native stacks, lists and ScrollViews; camera preview ignores only the bottom safe area; controls inside safe areas | Screenshots on the smallest current iPhone (17e) and the largest (18 Pro Max): every screen fits, nothing scrolls sideways |
| Touch controls | Standard buttons, segmented picker, toggles, sheets, swipe actions, menus; no gesture-only controls | Walkthrough UI tests drive every flow with plain taps |
| Hit targets at least 44 x 44 pt | Shutter 84 pt; picker and auto buttons at least 64 pt; map pins, trail markers, POIs and close buttons wrapped in `.frame(minWidth: 44, minHeight: 44)`; status buttons `minHeight: 44`; phone link 44 pt | Audit flagged the phone link (fixed). The only remaining item is Apple Maps' own "Legal" attribution link. |
| Text size at least 11 pt, Dynamic Type | Only text styles (`.caption2` = 11 pt at the default size); no fixed point sizes in body text; multiline text fields; rows switch to vertical layouts at accessibility sizes | Largest accessibility size screenshots (`iphone-17-light-accessibility-extra-extra-extra-large/`): every screen scales and the full walkthrough passes at that size. Audit flagged fixed 64 pt control frames and a one-line species name (fixed). Its remaining "partially unsupported" notes are on toolbar buttons and a list section header (system-rendered) and on Ranger rows that the giant-text screenshots show scaling. |
| Contrast, light and dark mode, text over camera and map | Guidance pill on a dark scrim over the camera; map hints on an opaque 94% system background; badge text uses darker shades than the tints; primary buttons are solid forest green with white text (not glass); system colours elsewhere | Audit (final run 13 Oct 01:10): "New" badge, map hint, Directions button and the result's Discard button failed and were fixed. Still listed: the Settings "Done" toolbar button (iOS 26 renders toolbar buttons on translucent glass, so the measured contrast depends on what scrolls beneath; it is a prominent tinted button), one Visit caption that the audit measured while it sat under the floating tab bar, and one Learn element the audit could not name. "Nearly passed" items are Apple's own secondary label colour. |
| Spacing, no overlapping text | 16 pt card padding; the only absolute layout is the decorative framing guide | Screenshots at three sizes and the largest text size |
| High resolution assets | SF Symbols and SwiftUI-drawn shapes only; 1024 px app icon in the asset catalog | Asset catalog compiles; icon renders on the simulator home screen |
| Image distortion | `scaledToFill` with `.clipped()` or `scaledToFit`; thumbnails keep aspect | Result, report and row screenshots |
| Organization: controls next to the content they change, one primary action per screen | Save on the result, Send in Reports, shutter on Scan, status grid on the report | Screenshots |
| Alignment | Leading-aligned text columns, consistent card layout | Screenshots |
| VoiceOver labels and hints | Labels on shutter, picker, pins ("Chinese privet, new report"), trail markers, guidance pill (`updatesFrequently`), badges; rows combined into one element | Audit found no missing element descriptions |
| Dark mode | System colours and materials; accent colour has a dark variant | iPhone 18 Pro Max dark screenshots: all screens legible |
| Reduce Motion | Framing-guide animation disabled when Reduce Motion is on; no other custom animation | Code review (`FramingGuide`) |
| Haptics | `.sensoryFeedback` on lock-on and save, plus an app toggle | Needs the phone (simulator has no haptics) |
| Colour never the only signal | Status = shape + colour + text; tier badges carry text | Screenshots of pins, badges and the result header |
| Empty, loading and error states | `ContentUnavailableView` for no reports; capture and identify overlays; alerts for camera and export errors; camera-denied screen with a Settings link | Empty Reports and Ranger states seen in the walkthrough; overlays exercised by the sample-photo path |

Motion: every animation (launch sequence, lock-on ripple, marching guide, capture flash, staged reveals, springing pins, staggered rows) checks `accessibilityReduceMotion` and falls back to a plain fade or no motion.

Open items: haptics and the live camera guidance can only be checked on the phone (Oct 16 checkpoint).
