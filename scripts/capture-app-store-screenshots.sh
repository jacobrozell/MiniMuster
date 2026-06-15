#!/usr/bin/env bash
# Capture App Store marketing screenshots via UI test automation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

IPHONE_DESTINATION="${IPHONE_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro Max}"
IPAD_DESTINATION="${IPAD_DESTINATION:-platform=iOS Simulator,name=iPad Pro 13-inch (M5)}"
STAGING="$ROOT/.app-store-screenshots/_staging"
BASE_OUT="$ROOT/.app-store-screenshots"

usage() {
  cat <<EOF
Usage: $(basename "$0") [device] [variant] [--skip-generate]

Device (pick one):
  --iphone          iPhone 17 Pro Max (default)
  --ipad            iPad Pro 13-inch (M5)
  --all             Both devices

Variant (pick one):
  --light           Light appearance (default)
  --dark            Dark appearance
  --accessibility   Largest Dynamic Type (AX5)
  --all-variants    light, dark, and accessibility

Output layout:
  .app-store-screenshots/iphone/{light,dark,accessibility}/
  .app-store-screenshots/ipad/{light,dark,accessibility}/

Examples:
  $(basename "$0") --all --all-variants
  $(basename "$0") --iphone --dark
  $(basename "$0") --ipad --accessibility

Environment overrides:
  IPHONE_DESTINATION   xcodebuild -destination for iPhone
  IPAD_DESTINATION     xcodebuild -destination for iPad
  OUT_DIR              output directory (single run only)
  DESTINATION          legacy alias for IPHONE_DESTINATION
EOF
}

sim_udid_for_destination() {
  local destination="$1"
  local sim_name
  sim_name=$(sed -n 's/.*name=\([^,]*\).*/\1/p' <<<"$destination")
  [[ -n "$sim_name" ]] || return 1
  xcrun simctl list devices available -j \
    | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next((dev['udid'] for _,devs in d.items() for dev in devs if dev.get('name')==sys.argv[1] and dev.get('isAvailable')), ''))" \
      "$sim_name" 2>/dev/null
}

set_sim_appearance() {
  local destination="$1"
  local variant="$2"
  local appearance="light"
  [[ "$variant" == "dark" ]] && appearance="dark"

  local udid
  udid=$(sim_udid_for_destination "$destination") || return 0
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl ui "$udid" appearance "$appearance"
}

capture() {
  local device="$1"
  local destination="$2"
  local variant="$3"
  local out_dir="$4"

  rm -rf "$STAGING"
  mkdir -p "$STAGING" "$out_dir"
  set_sim_appearance "$destination" "$variant"

  echo "Capturing $device / $variant → $out_dir"
  echo "Destination: $destination"
  echo

  local test_name="MiniMusterUITests/AppStoreScreenshotsUITests/testCaptureAppStoreScreenshots"
  case "$variant" in
    light) test_name+="Light" ;;
    dark) test_name+="Dark" ;;
    accessibility) test_name+="Accessibility" ;;
  esac

  SCREENSHOTS_DIR="$STAGING" xcodebuild test \
    -project MiniMuster.xcodeproj \
    -scheme MiniMuster \
    -destination "$destination" \
    -parallel-testing-enabled NO \
    -only-testing:"$test_name"

  cp "$STAGING"/*.png "$out_dir/"
  rm -rf "$STAGING"

  echo
  echo "Saved $(ls -1 "$out_dir"/*.png 2>/dev/null | wc -l | tr -d ' ') screenshots:"
  ls -1 "$out_dir"
  echo
}

MODE="iphone"
VARIANT_MODE="light"
SKIP_GENERATE=0

for arg in "$@"; do
  case "$arg" in
    --iphone) MODE="iphone" ;;
    --ipad) MODE="ipad" ;;
    --all) MODE="all" ;;
    --light) VARIANT_MODE="light" ;;
    --dark) VARIANT_MODE="dark" ;;
    --accessibility) VARIANT_MODE="accessibility" ;;
    --all-variants) VARIANT_MODE="all-variants" ;;
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

VARIANTS=()
case "$VARIANT_MODE" in
  light) VARIANTS=(light) ;;
  dark) VARIANTS=(dark) ;;
  accessibility) VARIANTS=(accessibility) ;;
  all-variants) VARIANTS=(light dark accessibility) ;;
esac

DEVICES=()
DESTINATIONS=()
case "$MODE" in
  iphone)
    DEVICES=(iphone)
    DESTINATIONS=("${DESTINATION:-$IPHONE_DESTINATION}")
    ;;
  ipad)
    DEVICES=(ipad)
    DESTINATIONS=("${DESTINATION:-$IPAD_DESTINATION}")
    ;;
  all)
    DEVICES=(iphone ipad)
    DESTINATIONS=("$IPHONE_DESTINATION" "$IPAD_DESTINATION")
    ;;
esac

for i in "${!DEVICES[@]}"; do
  device="${DEVICES[$i]}"
  destination="${DESTINATIONS[$i]}"
  for variant in "${VARIANTS[@]}"; do
    out_dir="${OUT_DIR:-$BASE_OUT/$device/$variant}"
    # OUT_DIR only applies to a single device+variant run.
    if [[ -n "${OUT_DIR:-}" && ( "${#DEVICES[@]}" -gt 1 || "${#VARIANTS[@]}" -gt 1 ) ]]; then
      echo "OUT_DIR is ignored when capturing multiple devices or variants." >&2
      out_dir="$BASE_OUT/$device/$variant"
    fi
    capture "$device" "$destination" "$variant" "$out_dir"
  done
done
