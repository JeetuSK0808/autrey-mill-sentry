#!/bin/bash
# Capture three frames of the launch animation straight from the simulator (XCTest cannot: it waits for idle).
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
cd "$(dirname "$0")/.."
SIM=${1:-iPhone 17}; OUT=docs/screenshots/launch; mkdir -p "$OUT"
xcrun simctl boot "$SIM" 2>/dev/null; sleep 3
xcrun simctl terminate "$SIM" com.jeetusk.autreymillsentry 2>/dev/null
xcrun simctl launch "$SIM" com.jeetusk.autreymillsentry -uiTesting -skipOnboarding -showLaunch >/dev/null 2>&1 &
sleep 0.4; xcrun simctl io "$SIM" screenshot "$OUT/launch-0.4s.png" >/dev/null 2>&1
sleep 0.5; xcrun simctl io "$SIM" screenshot "$OUT/launch-0.9s.png" >/dev/null 2>&1
sleep 0.5; xcrun simctl io "$SIM" screenshot "$OUT/launch-1.4s.png" >/dev/null 2>&1
sleep 0.6; xcrun simctl io "$SIM" screenshot "$OUT/launch-2.0s.png" >/dev/null 2>&1
wait; ls "$OUT"
