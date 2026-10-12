#!/bin/bash
# Build, install and launch on the connected iPhone from the command line (after Jeetu set the signing team in Xcode once).
# Usage: tools/build_device.sh [device-name-or-udid]
set -e
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
cd "$(dirname "$0")/.."
DEV=${1:-}
if [ -z "$DEV" ]; then
  xcrun devicectl list devices
  echo "Pass the device name or identifier as the first argument."; exit 1
fi
xcodebuild -project AutreyMillSentry.xcodeproj -scheme AutreyMillSentry -configuration Debug -destination "id=$DEV" -derivedDataPath build/DerivedData -allowProvisioningUpdates build | tail -5
APP=$(find build/DerivedData/Build/Products/Debug-iphoneos -maxdepth 1 -name "AutreyMillSentry.app" | head -1)
xcrun devicectl device install app --device "$DEV" "$APP"
xcrun devicectl device process launch --device "$DEV" com.jeetusk.autreymillsentry
echo "Installed $(date). Free-ID builds expire after 7 days."
