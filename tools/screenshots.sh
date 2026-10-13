#!/bin/bash
# Run the screenshot walkthrough on a simulator and export the PNGs to docs/screenshots/<sim>/ .
# Usage: tools/screenshots.sh "iPhone 17 Pro Max" [light|dark]
set -e
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
cd "$(dirname "$0")/.."
SIM=${1:-iPhone 17}; MODE=${2:-light}; SIZE=${3:-medium}
SLUG=$(echo "$SIM-$MODE-$SIZE" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/-medium$//')
OUT=docs/screenshots/$SLUG; RES=build/screens-$SLUG.xcresult
rm -rf "$RES" "$OUT"; mkdir -p "$OUT"
xcrun simctl boot "$SIM" 2>/dev/null || true
sleep 3
xcrun simctl ui "$SIM" appearance "$MODE" 2>/dev/null || true
xcrun simctl ui "$SIM" content_size "$SIZE" 2>/dev/null || true
xcodebuild -project AutreyMillSentry.xcodeproj -scheme AutreyMillSentry -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath build/DerivedData -resultBundlePath "$RES" -parallel-testing-enabled NO -only-testing:AutreyMillSentryUITests/ScreenshotUITests test 2>&1 | grep -E "Test Case|error:|passed|failed" | tail -20
xcrun xcresulttool export attachments --path "$RES" --output-path "$OUT" >/dev/null
# name files by attachment name
~/miniforge3/bin/python3 -I - "$OUT" <<'PY'
import json, pathlib, shutil, sys
out = pathlib.Path(sys.argv[1]); m = out / "manifest.json"
if m.exists():
    for entry in json.load(open(m)):
        for a in entry.get("attachments", []):
            src = out / a["exportedFileName"]; name = a.get("suggestedHumanReadableName") or a["exportedFileName"]
            dst = out / (pathlib.Path(name).stem.split("_")[0] + ".png")
            if src.exists(): shutil.move(src, dst)
print(sorted(p.name for p in out.glob("*.png")))
PY
xcrun simctl ui "$SIM" content_size medium 2>/dev/null || true
xcrun simctl ui "$SIM" appearance light 2>/dev/null || true
