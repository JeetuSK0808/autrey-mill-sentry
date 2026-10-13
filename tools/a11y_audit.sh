#!/bin/bash
# Run the XCTest accessibility audit on a simulator and write the findings to docs/accessibility_audit.txt
set -e
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
cd "$(dirname "$0")/.."
SIM=${1:-iPhone 17}; RES=build/a11y.xcresult; OUT=build/a11y-attachments
rm -rf "$RES" "$OUT"; mkdir -p "$OUT"
xcodebuild -project AutreyMillSentry.xcodeproj -scheme AutreyMillSentry -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath build/DerivedData -resultBundlePath "$RES" -parallel-testing-enabled NO -only-testing:AutreyMillSentryUITests/AccessibilityAuditUITests test 2>&1 | grep -E "Test Case|error:|passed|failed" | tail -12
xcrun xcresulttool export attachments --path "$RES" --output-path "$OUT" >/dev/null || true
{
  echo "# Accessibility audit (XCTest performAccessibilityAudit, $SIM, $(date '+%Y-%m-%d %H:%M'))"
  echo
  for f in "$OUT"/*.txt; do [ -f "$f" ] && cat "$f" && echo; done
  echo
  echo "Issues above are the raw audit output. Each one is either fixed or explained in docs/DESIGN_CHECKLIST.md."
} > docs/accessibility_audit.txt
grep -c "^\[\|: \[" docs/accessibility_audit.txt || true
