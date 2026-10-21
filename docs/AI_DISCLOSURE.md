# AI usage disclosure (DRAFT for the team to review and edit before submission)

The Congressional App Challenge rules (2025 rulebook, "AI USAGE") permit AI tools "provided that all AI usage is fully disclosed in the submission materials", say AI "must not constitute the entirety of the technical development", and expect "significant individual contributions and technical understanding" from the students. This file is the disclosure. It must be true when submitted; edit it to match what the team actually did.

## What AI did
Claude (Anthropic's Claude Code, model Claude Fable 5.1) was used as a coding assistant throughout, directed by Jeetu SK from a written build specification (`BUILT-PROMPT.md`). It wrote the first versions of most source files in `AutreyMillSentry/`, `model/`, `tools/` and `dashboard/`, the unit and UI tests, and most of the documentation; it ran the training and evaluation pipeline on the team's Mac; and it is credited in the git history (`Co-Authored-By` lines on the commits it wrote).

## What the team did
(Fill in truthfully, one line per person. Examples of the kinds of things that count, keep only what is real.)
- Jeetu SK: idea and problem definition from living next to the preserve; contact with preserve staff and the request for the staff dashboard; the species and data decisions (which natives, which invasive list, licence rules); the build specification and every design decision in it; field testing on the trail with the diagnostics overlay and the resulting fixes; the phone setup, builds and installs; the video.
- Teammate 2: ...
- Teammate 3: ...

## What the team can explain
Every member can walk through the scan pipeline (`Scanner/`), the four-outcome decision (`ScanDecision.swift`), the lock-on window, the observer-level split and calibration in `model/`, the priority score and the dashboard API, and can answer questions about any of them.

## External tools and libraries (documented per the Originality rule)
Apple SwiftUI, SwiftData, MapKit, Vision, Core ML; PyTorch, timm (EfficientNet-B0, ImageNet-pretrained weights), coremltools, torchvision, scipy; Next.js, React, Leaflet, Vercel Blob. Data: iNaturalist research-grade photos under CC0, CC BY and CC BY-NC (credits in `docs/LICENSES.md`), OpenStreetMap (ODbL), the Georgia Invasive Species Council list, the Georgia Forestry Commission Dirty Dozen.
