#!/usr/bin/env bash
# Capture App Store marketing screenshots via UI test automation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
OUT_DIR="${OUT_DIR:-$ROOT/.app-store-screenshots/iphone}"
STAGING="$ROOT/.app-store-screenshots/_staging"

rm -rf "$STAGING"
mkdir -p "$STAGING" "$OUT_DIR"

if [[ "${1:-}" != "--skip-generate" ]]; then
  xcodegen generate
fi

echo "Capturing screenshots → $OUT_DIR"
echo "Destination: $DESTINATION"
echo

SCREENSHOTS_DIR="$OUT_DIR" xcodebuild test \
  -project MusterRoll.xcodeproj \
  -scheme MusterRoll \
  -destination "$DESTINATION" \
  -parallel-testing-enabled NO \
  -only-testing:MusterRollUITests/AppStoreScreenshotsUITests/testCaptureAppStoreScreenshots

cp "$STAGING"/*.png "$OUT_DIR/" 2>/dev/null || true
rm -rf "$STAGING"

echo
echo "Screenshots saved:"
ls -la "$OUT_DIR"
