# MiniMuster — iOS

Native SwiftUI app for tracking Warhammer armies, painting progress, and paint inventory.

**v1.0.0** — local-first, web-compatible import/export, home-screen widget, iPad split view.

| | |
|---|---|
| **Platform** | iOS 18+ (iPhone & iPad) |
| **Stack** | Swift 6, SwiftUI, SwiftData |
| **Data** | On-device only — no account, no cloud sync |
| **Web parity** | CSV + JSON backup round-trip with the [MiniMuster web app](https://github.com/jacobrozell/MiniMuster) |

## What it does

- **Collection** — armies, units, squad members, custom pipelines, search, filters, overview stats
- **Paints** — inventory with list/grid views, filters, and deep links into the collection
- **Settings** — theme, global pipeline, faction crest overrides, import/export/backup
- **Widget** — “On the sprue” count on the home screen
- **Accessibility** — VoiceOver, Dynamic Type (including AX5), dark mode, Reduce Motion

## Requirements

- macOS with **Xcode 16+** (Swift 6, iOS 18 SDK)
- [XcodeGen](https://github.com/yonsson/XcodeGen) — project file is generated locally and not committed
- Apple Developer account — required for device builds and App Group entitlements (widget)

## Quick start

```bash
brew install xcodegen
cd ios
xcodegen generate
open MiniMuster.xcodeproj
```

In Xcode: select the **MiniMuster** scheme, pick an iOS 18 simulator (e.g. iPhone 17), and run (⌘R).

**First launch:** use **Load sample data** on the empty collection screen or from Settings → Data to explore with demo armies and paints.

## Project layout

```
MiniMuster/
  App/              RootView, AppRouter, AppContainer, splash & onboarding
  Models/           SwiftData models (Army, Unit, SquadMember, Paint, AppConfiguration)
  Domain/           Pipeline, filters, factions, stats (pure Swift, no UI)
  DataIO/           CSV import/export, JSON backup, demo loader
  Features/
    Collection/     Army list → unit list → unit detail (split view on iPad)
    Paints/         Paint list/grid → paint detail
    Settings/       Theme, pipeline, data import/export, about
  DesignSystem/     ProgressRing, StateChip, tokens, adaptive layout
  Widget/           App Group snapshot writer (shared with widget extension)
  Support/          BannerCenter, UndoService, deep links
MiniMusterWidget/   “On the sprue” home-screen widget extension
MiniMusterTests/    Swift Testing — domain, stores, I/O (~180 tests)
MiniMusterUITests/  Launch smoke tests + App Store screenshot automation
scripts/            test-coverage.sh, capture-app-store-screenshots.sh
docs/               Privacy, accessibility, App Store metadata, release plan
```

`MusterRoll/` is a legacy target tree from an earlier rename; **MiniMuster** is the shipping app.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  SwiftUI (Features/)     TabView + NavigationSplitView  │
├─────────────────────────────────────────────────────────┤
│  Domain/                 Pipeline, filters, factions    │
├─────────────────────────────────────────────────────────┤
│  DataIO/                 CSV, JSON backup, DemoLoader   │
├─────────────────────────────────────────────────────────┤
│  SwiftData (Models/)     Army, Unit, Paint, config      │
├─────────────────────────────────────────────────────────┤
│  App Group               WidgetDataStore → widget ext.  │
└─────────────────────────────────────────────────────────┘
```

- **SwiftData** persists all user data on device.
- **Domain/** holds business logic ported from the web app’s `js/` layer; tests target this heavily.
- **DataIO/** implements the same CSV columns and JSON backup shape as the web app so files round-trip.
- **Widget** reads model counts from `group.com.jacobrozell.minimuster` via `WidgetDataStore`.

See [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) for targets, signing, UI-test launch arguments, and CI details.

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

CI runs the full coverage script on `macos-15` with the iPhone 17 simulator and uploads the summary as a workflow artifact (see [`.github/workflows/ios.yml`](.github/workflows/ios.yml)).

## Data import & export

Settings → **Data** supports:

| Action | Format | Notes |
|--------|--------|-------|
| Export armies CSV | `.csv` | Same columns as the web app |
| Export paints CSV | `.csv` | Same columns as the web app |
| Full backup | `.json` | Armies, paints, pipeline, theme, overrides |
| Restore backup | `.json` | Replaces all local data |
| Import armies/paints | `.csv` | Replace or append |

Bundled templates are available for empty exports. See [`docs/DATA_FORMATS.md`](docs/DATA_FORMATS.md) for column schemas and backup structure.

## App Store screenshots

Automated capture via UI tests:

```bash
# Everything (recommended before upload)
./scripts/capture-app-store-screenshots.sh --all --all-variants

# Single device / variant
./scripts/capture-app-store-screenshots.sh --iphone --dark
./scripts/capture-app-store-screenshots.sh --ipad --accessibility
```

Output: `.app-store-screenshots/{iphone,ipad}/{light,dark,accessibility}/` — six PNGs per folder. See [`docs/APP_STORE.md`](docs/APP_STORE.md) for device sizes and upload checklist.

## Privacy

- In-app: **Settings → Privacy Policy**
- Canonical document: [`docs/PRIVACY.md`](docs/PRIVACY.md)
- **App Store URL:** [`docs/privacy.html`](docs/privacy.html) at `https://jacobrozell.github.io/MiniMuster/privacy.html`

The app is local-first: no accounts, no analytics, no network transmission of your collection data.

## Documentation

| Document | Purpose |
|----------|---------|
| [`docs/README.md`](docs/README.md) | Documentation index |
| [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) | Build, targets, signing, testing, CI |
| [`docs/DATA_FORMATS.md`](docs/DATA_FORMATS.md) | CSV columns & JSON backup schema |
| [`docs/APP_STORE.md`](docs/APP_STORE.md) | App Store Connect metadata draft |
| [`docs/RELEASE_1.0.0.md`](docs/RELEASE_1.0.0.md) | Release checklist & regression steps |
| [`docs/PRIVACY.md`](docs/PRIVACY.md) | Privacy policy (bundled in app) |
| [`docs/accessibility.html`](docs/accessibility.html) | Accessibility statement (GitHub Pages) |
| [`docs/BARCODE_SCANNER.md`](docs/BARCODE_SCANNER.md) | Future feature spec (post-1.0) |

## Version history

| Version | Notes |
|---------|--------|
| **1.0.0** | Native redesign complete; production layout/a11y polish, widget, UI tests |
| 0.x | Web-parity port (M1–M7) + native overhaul Phases 1–4 |

## Contact

Questions or feedback: [jacob.rozell83@gmail.com](mailto:jacob.rozell83@gmail.com)
