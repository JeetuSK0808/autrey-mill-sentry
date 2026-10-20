#!/bin/bash
# Build and test on the Simulator. Usage: tools/build_sim.sh [build|test|uitest] [simulator name]
set -e
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
cd "$(dirname "$0")/.."
ACTION=${1:-build}; SIM=${2:-iPhone 17}
case "$ACTION" in
  build) xcodebuild -project AutreyMillSentry.xcodeproj -scheme AutreyMillSentry -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath build/DerivedData build 2>&1 | grep -E "error:|warning:|BUILD" ;;
  test) xcodebuild -project AutreyMillSentry.xcodeproj -scheme AutreyMillSentry -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath build/DerivedData -only-testing:AutreyMillSentryTests test 2>&1 | grep -E "error:|Test Case|passed|failed|TEST" ;;
  uitest) xcodebuild -project AutreyMillSentry.xcodeproj -scheme AutreyMillSentry -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath build/DerivedData -only-testing:AutreyMillSentryUITests test 2>&1 | grep -E "error:|Test Case|passed|failed|TEST" ;;
esac
