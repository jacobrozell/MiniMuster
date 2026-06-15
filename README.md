# MiniMuster — iOS

Native SwiftUI app for tracking Warhammer armies, painting progress, and paint inventory.
**v1.0.0** — local-first, web-compatible import/export.

Specs: [`docs/ios-native/`](../docs/ios-native/) (UI/UX) · [`docs/ios-spec/`](../docs/ios-spec/) (data/domain parity)

## Requirements

- Xcode 16+ (Swift 6, iOS 18 SDK)
- [XcodeGen](https://github.com/yonsson/XcodeGen)

## Setup

```bash
brew install xcodegen
cd ios
xcodegen generate
open MiniMuster.xcodeproj
```

The `.xcodeproj` is generated locally and not committed.

## Tests

```bash
cd ios
xcodegen generate

# All tests + code coverage report
./scripts/test-coverage.sh

# Per-file breakdown
./scripts/test-coverage.sh --files

# Enforce a minimum app coverage threshold (optional)
MIN_COVERAGE=40 ./scripts/test-coverage.sh
```

Reports land in `.coverage/` (gitignored). Open `.coverage/TestResults.xcresult` in Xcode for line-by-line highlighting.

Individual suites:

```bash
# Unit tests
xcodebuild test -project MiniMuster.xcodeproj -scheme MiniMuster \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MiniMusterTests -parallel-testing-enabled NO

# UI smoke tests
xcodebuild test -project MiniMuster.xcodeproj -scheme MiniMuster \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MiniMusterUITests -parallel-testing-enabled NO
```

CI runs the full coverage script on `macos-15` with the iPhone 17 simulator and uploads the summary as a workflow artifact (see `.github/workflows/ios.yml`).

## App structure

```
MiniMuster/
  App/              RootView, AppRouter, AppContainer
  Models/           SwiftData models
  Domain/           Pipeline, filters, factions (pure Swift)
  DataIO/           CSV import/export, JSON backup
  Features/
    Collection/     Army list → unit list → unit detail (split view)
    Paints/         Paint list/grid → paint detail
    Settings/       Theme, pipeline, data import/export
  DesignSystem/     ProgressRing, StateChip, components
  Widget/           App Group snapshot for home-screen widget
  Support/          BannerCenter, UndoService
MiniMusterWidget/   “On the sprue” widget extension
MiniMusterTests/    Swift Testing (domain + stores + I/O)
MiniMusterUITests/  Launch, sample data, tab navigation smoke tests
```

## Features (v1.0)

**Collection** — searchable army list, filter sheet, overview stats, swipe-to-delete armies. Drill into an army for unit list with swipe advance/duplicate/delete, edit-mode multi-select batch advance, and unit detail form (squad tracking, spearhead, notes).

**Paints** — list or grid, search, filters, CRUD, source link to filter collection.

**Settings** — appearance, global pipeline, faction crest overrides, all import/export/backup/clear/sample data.

**Platform** — iPhone + iPad `NavigationSplitView`, undo, banner feedback, home-screen widget (sprue model count).

Data formats match the web app: armies/paints CSV and full JSON backup.

## Privacy

- In-app: **Settings → Privacy Policy**
- Canonical document: [`docs/PRIVACY.md`](docs/PRIVACY.md)
- **App Store URL:** [`docs/privacy.html`](docs/privacy.html) at `https://jacobrozell.github.io/MiniMuster/privacy.html`

The app is local-first: no accounts, no analytics, no network transmission of your collection data.

## App Store prep

- **Metadata draft:** [`docs/APP_STORE.md`](docs/APP_STORE.md) — description, keywords, nutrition labels, review notes
- **Screenshots:** `./scripts/capture-app-store-screenshots.sh --all` → `.app-store-screenshots/iphone/` + `.app-store-screenshots/ipad/` (6 PNGs each)
- **Release checklist:** [`docs/RELEASE_1.0.0.md`](docs/RELEASE_1.0.0.md)

## Version history

| Version | Notes |
|---------|--------|
| **1.0.0** | Native redesign complete; production layout/a11y polish, widget, UI tests |
| 0.x | Web-parity port (M1–M7) + native overhaul Phases 1–4 |
