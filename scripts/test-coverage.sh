#!/usr/bin/env bash
# Run all unit + UI tests with code coverage and write a summary report.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
COVERAGE_DIR="$ROOT/.coverage"
RESULT_BUNDLE="$COVERAGE_DIR/TestResults.xcresult"
SUMMARY="$COVERAGE_DIR/coverage-summary.txt"
JSON="$COVERAGE_DIR/coverage.json"
FILES="$COVERAGE_DIR/coverage-by-file.txt"
MIN_COVERAGE="${MIN_COVERAGE:-}"

show_files=false
skip_generate=false

usage() {
  cat <<'EOF'
Usage: scripts/test-coverage.sh [options]

Run MiniMuster unit and UI tests with code coverage enabled.

Options:
  --files           Include per-file coverage breakdown for MiniMuster
  --skip-generate   Skip xcodegen (use existing .xcodeproj)
  -h, --help        Show this help

Environment:
  DESTINATION       xcodebuild destination (default: iPhone 17 simulator)
  MIN_COVERAGE      Fail if MiniMuster coverage is below this percentage (e.g. 40)

Outputs:
  .coverage/TestResults.xcresult   Raw xcresult bundle (open in Xcode)
  .coverage/coverage-summary.txt   Per-target line coverage
  .coverage/coverage.json          Machine-readable report
  .coverage/coverage-by-file.txt   Per-file report (--files only)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --files) show_files=true; shift ;;
    --skip-generate) skip_generate=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ "$skip_generate" == false ]]; then
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen is required. Install with: brew install xcodegen" >&2
    exit 1
  fi
  xcodegen generate
fi

rm -rf "$COVERAGE_DIR"
mkdir -p "$COVERAGE_DIR"

echo "Running tests with coverage → $RESULT_BUNDLE"
echo "Destination: $DESTINATION"
echo

xcodebuild test \
  -project MiniMuster.xcodeproj \
  -scheme MiniMuster \
  -destination "$DESTINATION" \
  -parallel-testing-enabled NO \
  -enableCodeCoverage YES \
  -resultBundlePath "$RESULT_BUNDLE"

echo
echo "=== Code coverage (by target) ==="
xcrun xccov view --report --only-targets "$RESULT_BUNDLE" | tee "$SUMMARY"

xcrun xccov view --report --json "$RESULT_BUNDLE" > "$JSON"

if [[ "$show_files" == true ]]; then
  echo
  echo "=== Code coverage (MiniMuster, by file) ==="
  xcrun xccov view --report --files-for-target MiniMuster "$RESULT_BUNDLE" | tee "$FILES"
fi

if [[ -n "$MIN_COVERAGE" ]]; then
  echo
  if ! app_coverage="$(python3 - "$JSON" "$MIN_COVERAGE" <<'PY'
import json, sys
path, minimum = sys.argv[1], float(sys.argv[2])
with open(path) as f:
    data = json.load(f)
targets = {t["name"]: t["lineCoverage"] * 100 for t in data.get("targets", [])}
pct = targets.get("MiniMuster.app") or targets.get("MiniMuster")
if pct is None:
    print("MiniMuster target not found in coverage report", file=sys.stderr)
    sys.exit(2)
print(f"{pct:.1f}")
if pct < minimum:
    sys.exit(1)
PY
)"; then
    echo "MiniMuster coverage below minimum (${MIN_COVERAGE}%)" >&2
    exit 1
  fi
  echo "MiniMuster coverage: ${app_coverage}% (minimum: ${MIN_COVERAGE}%)"
fi

echo
echo "Reports written to $COVERAGE_DIR"
echo "Open in Xcode: open \"$RESULT_BUNDLE\""
