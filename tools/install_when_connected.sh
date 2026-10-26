#!/bin/bash
# Waits for the iPhone, then builds, installs and launches the app. Retries while the phone stays attached
# (the build needs the phone unlocked for its first minute). Usage: tools/install_when_connected.sh [udid]
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
cd "$(dirname "$0")/.."
UDID=${1:?usage: tools/install_when_connected.sh <device-udid>}
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
    if xcrun devicectl device install app --device "$UDID" "$APP" > build/device_install_out.txt 2>&1; then
      echo "INSTALLED $(date). Free-ID build expires in 7 days."
      if xcrun devicectl device process launch --terminate-existing --device "$UDID" "$BUNDLE" > build/device_launch_out.txt 2>&1; then
        echo "LAUNCHED $(date)"
      else
        echo "installed but not launched (phone locked?): $(grep -m1 -o 'Unable to launch[^.]*' build/device_launch_out.txt). Open the app by hand."
      fi
      exit 0
    fi
    echo "install failed $(date): $(tail -1 build/device_install_out.txt | cut -c1-160), retrying"
  else
    echo "build failed $(date): $(grep -m1 -E 'error:|ERROR' "$LOG" | cut -c1-160)"
  fi
  sleep 45
done
