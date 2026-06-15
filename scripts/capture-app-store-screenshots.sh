#!/usr/bin/env bash
# Capture App Store marketing screenshots via UI test automation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

IPHONE_DESTINATION="${IPHONE_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro Max}"
IPAD_DESTINATION="${IPAD_DESTINATION:-platform=iOS Simulator,name=iPad Pro 13-inch (M5)}"
STAGING="$ROOT/.app-store-screenshots/_staging"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--iphone | --ipad | --all] [--skip-generate]

Capture App Store screenshots into device-specific folders:
  .app-store-screenshots/iphone/   (default: iPhone 17 Pro Max)
  .app-store-screenshots/ipad/     (default: iPad Pro 13-inch M5)

Environment overrides:
  IPHONE_DESTINATION   xcodebuild -destination for iPhone captures
  IPAD_DESTINATION     xcodebuild -destination for iPad captures
  OUT_DIR              output directory (single-device runs only)
  DESTINATION          legacy alias for IPHONE_DESTINATION / IPAD_DESTINATION
EOF
}

capture() {
  local destination="$1"
  local out_dir="$2"

  rm -rf "$STAGING"
  mkdir -p "$STAGING" "$out_dir"

  echo "Capturing screenshots → $out_dir"
  echo "Destination: $destination"
  echo

  SCREENSHOTS_DIR="$out_dir" xcodebuild test \
    -project MusterRoll.xcodeproj \
    -scheme MusterRoll \
    -destination "$destination" \
    -parallel-testing-enabled NO \
    -only-testing:MusterRollUITests/AppStoreScreenshotsUITests/testCaptureAppStoreScreenshots

  cp "$STAGING"/*.png "$out_dir/" 2>/dev/null || true
  rm -rf "$STAGING"

  echo
  echo "Screenshots saved:"
  ls -la "$out_dir"
  echo
}

MODE="iphone"
SKIP_GENERATE=0

for arg in "$@"; do
  case "$arg" in
    --iphone) MODE="iphone" ;;
    --ipad) MODE="ipad" ;;
    --all) MODE="all" ;;
    --skip-generate) SKIP_GENERATE=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$SKIP_GENERATE" -eq 0 ]]; then
  xcodegen generate
fi

case "$MODE" in
  iphone)
    capture "${DESTINATION:-$IPHONE_DESTINATION}" "${OUT_DIR:-$ROOT/.app-store-screenshots/iphone}"
    ;;
  ipad)
    capture "${DESTINATION:-$IPAD_DESTINATION}" "${OUT_DIR:-$ROOT/.app-store-screenshots/ipad}"
    ;;
  all)
    capture "$IPHONE_DESTINATION" "$ROOT/.app-store-screenshots/iphone"
    capture "$IPAD_DESTINATION" "$ROOT/.app-store-screenshots/ipad"
    ;;
esac
