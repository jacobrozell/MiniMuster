# Development guide — MiniMuster iOS

Technical reference for building, testing, and shipping the app.

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Xcode | 16+ | Mac App Store |
| XcodeGen | latest | `brew install xcodegen` |
| iOS Simulator | iOS 18 runtime | Xcode → Settings → Platforms |

The project targets **iOS 18.0** with **Swift 6** and `SWIFT_STRICT_CONCURRENCY: complete`.

## Generate & open

```bash
cd ios
xcodegen generate    # reads project.yml → MiniMuster.xcodeproj
open MiniMuster.xcodeproj
```

Re-run `xcodegen generate` after changing `project.yml` (new files under existing source paths are picked up automatically).

## Targets

| Target | Type | Bundle ID |
|--------|------|-----------|
| **MiniMuster** | App | `com.jacobrozell.minimuster` |
| **MiniMusterWidget** | Widget extension | `com.jacobrozell.minimuster.widget` |
| **MiniMusterTests** | Unit tests | `com.jacobrozell.minimuster.tests` |
| **MiniMusterUITests** | UI tests | `com.jacobrozell.minimuster.uitests` |

Version numbers live in `project.yml`:

- `MARKETING_VERSION` — user-facing version (e.g. `1.0.0`)
- `CURRENT_PROJECT_VERSION` — build number

## Code organization

### App layer (`MiniMuster/App/`)

- `AppContainer` — SwiftData `ModelContainer` factory (production, preview, UI-test persistent)
- `RootView` — tab shell, onboarding, backup reminder, widget refresh
- `AppRouter` — tab selection and collection/paint navigation state
- `AppShell` — `@main` entry, environment setup

### Features (`MiniMuster/Features/`)

SwiftUI screens grouped by tab or flow. Collection uses `NavigationSplitView` on iPad (sidebar → content → detail).

### Domain (`MiniMuster/Domain/`)

Pure Swift logic with no SwiftUI imports:

- `Pipeline` — painting stages, advance/retreat, per-army overrides
- `ArmyFilter` / paint filters — search, quick views, sort
- `Factions` — crest/color resolution with user overrides
- `CollectionStats` — overview meters and counts

Ported from the web app’s `js/` modules; unit tests exercise this layer directly.

### DataIO (`MiniMuster/DataIO/`)

- `ArmyCSV` / `PaintCSV` — parse and serialize CSV (web-compatible columns)
- `BackupCodec` / `Snapshot` — JSON backup DTOs matching `exportSnapshot` in the web app
- `CollectionStore` — bulk replace/append for imports
- `DemoLoader` — bundled sample CSVs for “Load sample data”

### Design system (`MiniMuster/DesignSystem/`)

Shared components: `ProgressRing`, `StateChip`, `AdaptiveLayout`, semantic colors in `Assets.xcassets`.

### Support (`MiniMuster/Support/`)

- `BannerCenter` — transient success/info banners
- `UndoService` — single-level undo for state advances and deletes
- `AppDeepLink` — `minimuster://` URLs for widget → app navigation

## SwiftData models

| Model | Role |
|-------|------|
| `Army` | Name, game, faction, crest/color, optional custom pipeline |
| `Unit` | Name, qty, state, source, spearhead, notes, squad members |
| `SquadMember` | Per-model state and notes when qty > 1 |
| `Paint` | Name, type, brand, swatch, qty, source |
| `AppConfiguration` | Theme, global pipeline, faction overrides, backup timestamp |

Schema is defined in `AppContainer.schema`. Migrations are not yet required for 1.0.

## Widget & App Group

The widget extension cannot access SwiftData directly. The main app writes summary counts to a shared **App Group** container:

- Group ID: `group.com.jacobrozell.minimuster`
- Writer: `WidgetUpdater.refresh(context:)` after data changes
- Reader: `WidgetDataStore` (compiled into both app and widget targets)

**Before archiving for TestFlight/App Store:**

1. Register `group.com.jacobrozell.minimuster` in [Apple Developer → Identifiers → App Groups](https://developer.apple.com/account/resources/identifiers/list/applicationGroup).
2. Enable the group on both the app and widget App IDs.
3. Entitlements are in `MiniMuster.entitlements` and `MiniMusterWidget.entitlements`.

## UI testing

### Smoke tests (`MiniMusterUITests`)

Basic launch, sample data, and tab navigation. Run via scheme test action or `xcodebuild test`.

### Screenshot tests (`AppStoreScreenshotsUITests`)

Driven by `scripts/capture-app-store-screenshots.sh`. Environment variables:

| Variable | Purpose |
|----------|---------|
| `SCREENSHOTS_DIR` | Output directory for PNGs |
| `UI_TEST_VARIANT` | `light`, `dark`, or `accessibility` |

Launch arguments used internally:

| Argument | Effect |
|----------|--------|
| `UI-Testing` | In-memory or isolated store, skip delays |
| `UI-Testing-DarkTheme` | Force dark appearance |
| `UI-Testing-Accessibility` | Largest Dynamic Type (AX5) |
| `UI-Testing-SkipOnboarding` | Skip first-launch sheet |

Accessibility identifiers (examples): `tabCollection`, `tabPaints`, `onboardingSkip`, `army-{name}`.

## Testing & coverage

```bash
./scripts/test-coverage.sh           # full run
./scripts/test-coverage.sh --files   # per-file breakdown
MIN_COVERAGE=40 ./scripts/test-coverage.sh  # fail under threshold
```

Outputs in `.coverage/` (gitignored):

- `TestResults.xcresult` — open in Xcode for line coverage
- `coverage-summary.txt` — per-target percentages
- `coverage.json` — machine-readable

Unit tests use **Swift Testing** (`@Test`). Domain, CSV, backup, stores, and view smoke tests total ~180 cases. UI tests add launch and screenshot coverage.

## Continuous integration

[`.github/workflows/ios.yml`](../.github/workflows/ios.yml) on push/PR to `main`:

1. Select Xcode 16 on `macos-15`
2. `brew install xcodegen && xcodegen generate`
3. Build for iPhone 17 simulator
4. `./scripts/test-coverage.sh --skip-generate`
5. Upload coverage summary artifact

## Code signing

`project.yml` sets `DEVELOPMENT_TEAM` and automatic signing. For local device runs, sign in with your Apple ID in Xcode and ensure the team matches.

Widget requires the App Group capability on both targets — without it, widget builds fail or the extension reads stale zeros.

## Deep links

URL scheme: `minimuster://`

Used by the widget (`AppDeepLink.collectionBacklogURL`) to open the collection tab. Handled in `RootView.onOpenURL`.

## Bundled resources

| File | Purpose |
|------|---------|
| `Resources/warhammer_armies.csv` | Sample army data |
| `Resources/warhammer_paint_inventory.csv` | Sample paint data |
| `Resources/PRIVACY.md` | In-app privacy policy |
| `Resources/ACCESSIBILITY.md` | In-app accessibility statement |

Keep `docs/privacy.html`, `docs/accessibility.html`, and the bundled markdown copies aligned when updating legal text.

## Common tasks

### Bump version for release

1. Edit `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`
2. `xcodegen generate`
3. Verify Settings → About shows the new version (`Bundle.appVersion`)

### Regenerate launch assets

```bash
python3 scripts/generate-launch-assets.py
```

### Manual regression before ship

See the 10-step checklist in [RELEASE_1.0.0.md](RELEASE_1.0.0.md) — run on both iPhone and iPad.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `MiniMuster.xcodeproj` missing | Run `xcodegen generate` |
| Simulator not found | Install iOS 18 runtime; override `DESTINATION` env var |
| Widget shows 0 after data load | Confirm App Group registration; check entitlements |
| UI test flake on CI | Use `-parallel-testing-enabled NO` (already in scripts) |
| Import fails silently | 1.0 surfaces alerts — check file encoding (UTF-8) and size (&lt; `Limits.maxImportBytes`) |
