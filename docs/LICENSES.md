# Licenses and attribution

## This app
Autrey Mill Sentry, a student project by Jeetu SK built for Autrey Mill Nature Preserve. Source code license: to be chosen by Jeetu before submission (MIT suggested; see HANDOFF.md). The preserve has not endorsed or approved the app.

## Map data
Map data © OpenStreetMap contributors, available under the Open Database License (ODbL 1.0), https://www.openstreetmap.org/copyright . Retrieved 2026-10-12 via the Overpass API and Nominatim. Base map tiles © Apple Maps (MapKit).

## Training photographs (not redistributed)
Training images come from iNaturalist research-grade observations whose photos are licensed CC0, CC BY 4.0 or CC BY-NC 4.0 only. Images are used solely to train the on-device classifier and are not included in the app or the repository. Every image used is recorded in `data/attribution.csv` (observation id, photo id, observer, license, photo URL, observation URL); that file is kept locally and a per-observer summary is generated into this file by `tools/attribution_summary.py` before submission. Licence texts: https://creativecommons.org/publicdomain/zero/1.0/ , https://creativecommons.org/licenses/by/4.0/ , https://creativecommons.org/licenses/by-nc/4.0/ .

## Pretrained weights
The classifier is fine-tuned from the `mobilenetv3_large_100` ImageNet weights distributed by the timm library (Apache 2.0). PyTorch (BSD), torchvision (BSD), timm (Apache 2.0) and coremltools (BSD-3) are used only in the training pipeline, not in the app.

## Apple
SwiftUI, SwiftData, MapKit, Vision, Core ML, AVFoundation and SF Symbols are used under the Apple Developer agreement and the SF Symbols terms (symbols are not used as logos).

## Species lists and text sources
Georgia Invasive Species Council plant list; Georgia Forestry Commission Dirty Dozen; UGA Center for Invasive Species and Ecosystem Health (invasive.org) species pages; Lady Bird Johnson Wildflower Center plant database. Text in the app is written in the project's own words with links to the sources.

## Observer credits
(Generated at submission time by `tools/attribution_summary.py` from `data/attribution.csv`.)
