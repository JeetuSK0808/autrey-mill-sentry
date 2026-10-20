#!/bin/bash
# Waits for the iPhone, then builds, installs and launches the app. Retries while the phone stays attached
# (the build needs the phone unlocked for its first minute). Usage: tools/install_when_connected.sh [udid]
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
cd "$(dirname "$0")/.."
UDID=${1:-00008110-000948AA2299401E}
BUNDLE=com.jeetusk.autreymillsentry
LOG=build/device_install.log
mkdir -p build
state() { xcrun devicectl device info details --device "$UDID" 2>/dev/null | grep -o 'Device State: [a-z]*' | cut -d' ' -f3; }
while true; do
  until [ "$(state)" = "connected" ]; do sleep 20; done
  echo "phone connected $(date)"
  if xcodebuild -project AutreyMillSentry.xcodeproj -scheme AutreyMillSentry -configuration Debug -destination "id=$UDID" \
       -derivedDataPath build/DerivedData-device -allowProvisioningUpdates -destination-timeout 90 build >"$LOG" 2>&1; then
    APP=build/DerivedData-device/Build/Products/Debug-iphoneos/AutreyMillSentry.app
    if xcrun devicectl device install app --device "$UDID" "$APP" 2>&1 | tail -2 && \
       xcrun devicectl device process launch --terminate-existing --device "$UDID" "$BUNDLE" 2>&1 | tail -1; then
      echo "INSTALLED AND LAUNCHED $(date). Free-ID build expires in 7 days."; exit 0
    fi
    echo "install/launch failed $(date), retrying"
  else
    echo "build failed $(date): $(grep -m1 -E 'error:|ERROR' "$LOG" | cut -c1-160)"
  fi
  sleep 45
done
