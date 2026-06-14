# The Muster Roll — iOS (scaffold)

A starter SwiftUI / SwiftData / Swift Testing project implementing **Milestone 1
(Foundation)** of [`docs/ios-spec/`](../docs/ios-spec/). It compiles, launches to the
two-tab shell with empty states, and ships the full pure-logic core (models, pipeline,
progress, members, tags, source-match, faction catalogue) with unit tests.

This is a **working app**. Milestones **M1–M6** are implemented (foundation, Armies UI,
filters/search/sort, Paint Rack CRUD + per-model squad tracking, import/export/backup, and
settings/theming/undo). Only **M7** (test-coverage hardening + final a11y polish) remains —
see [`docs/ios-spec/12-roadmap-acceptance.md`](../docs/ios-spec/12-roadmap-acceptance.md).

## Generating the Xcode project

The `.xcodeproj` is **not** committed (it's a fragile generated artefact). Generate it with
[XcodeGen](https://github.com/yonsson/XcodeGen):

```bash
brew install xcodegen
cd ios
xcodegen generate
open MusterRoll.xcodeproj
```

Requirements: **Xcode 16+** (Swift 6, iOS 18 SDK).

## Running tests

```bash
cd ios
xcodegen generate
xcodebuild test -project MusterRoll.xcodeproj -scheme MusterRoll \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Layout

```
MusterRoll/
  App/            MusterRollApp, AppContainer, RootView
  Models/         SwiftData @Model classes + value types
  Domain/         pure logic (no SwiftData/SwiftUI imports) + faction catalogue
  Features/       Armies & Paints screens (M1: empty-state shells)
  DesignSystem/   colour tokens, Color(hex:)
MusterRollTests/  Swift Testing suites
```

## What's implemented (M1)

- `Army`, `Unit`, `SquadMember`, `Paint`, `AppConfiguration` SwiftData models (CloudKit-ready
  shape per `01-data-model.md §9`).
- `PipelineStage`, `FactionPresetOverride` value types; `safeColor`; `Color(hex:)`; `Limits`.
- `ModelCount`, `Pipeline` (progress / segments / advance), `Members`, `Tags`, `SourceMatch`.
- Full faction catalogue (`FactionDefs`) + `FactionResolver` (alias normalize, composite/flat
  resolution, fallback, override precedence).
- `AppContainer` (on-disk + in-memory preview), singleton `AppConfiguration`, theme applied at
  root.
- Two-tab `RootView`; Paint Rack shows a read-only grid (full CRUD is M-later).
- Swift Testing suites for the pure logic.

## What's implemented (M2 — Armies UI)

- `ArmyStatsHeader` (7 stat tiles + stacked collection meter & legend).
- `ArmyCard` (resolved crest + accent, name/meta/percent, collapse, army actions:
  reset theme / rename / delete) with a per-army stacked meter.
- `UnitRow` inline editing (name, source, qty stepper, tinted state menu, spearhead star,
  multiline notes) + row actions (advance, duplicate, move, remove) and squad summary.
- Footer actions: add unit, advance all, merge duplicates.
- Sheets: new army (game/faction pickers), add unit, rename army, move unit.
- `ArmyStore` mutations (add/rename/delete army, add/duplicate/move/delete unit, set state/
  qty/spearhead, advance, advance-all, merge duplicates, member resize) — undo-ready.
- Toolbar: new army, expand/collapse all.
- Swift Testing `ArmyStoreTests` for the mutations.

## What's implemented (M3 / M4 / M6)

- **M3 — Filters/search/sort:** `ArmyFilter` (visible-armies builder) + `ArmyFilterBar`
  (game/faction/state/source/tag menus, quick-view segmented control, spearhead toggle,
  sort pickers), debounced-style search, persisted prefs, scoped `(filtered)` stats,
  filtered-empty state, advance-visible.
- **M4 — Paint Rack + squads:** full paint CRUD (`PaintStore`, `AddEditPaintSheet`),
  type/brand/stock filters, scoped stats, source → Armies deep link (`AppRouter`); per-model
  squad expansion in `UnitRow` (`SquadStore`, `SquadMemberRow`).
- **M6 — Settings/theme/undo:** `SettingsScreen` (theme picker, global pipeline editor,
  faction crest/colour overrides), `UndoService` (delete unit/army, state change, bulk
  advance — wired to the Undo toolbar button), `ToastCenter`, and the 14-day backup reminder.
- Tests: `ArmyFilterTests`, `SquadStoreTests`, `PaintStoreTests`, `UndoServiceTests`.

## What's implemented (M5)

- `CSV` parser/writer (RFC-4180 quoting, BOM, CRLF, TSV/semicolon detection); `HeaderMap`
  and field normalizers.
- Armies + Paints CSV import (grouping, squad members, dup merge, warnings) and export.
- JSON full backup: web-compatible `Snapshot` DTOs, `BackupSanitizer` (size/strict-keys/cap/
  clamp/`safeColor`), `BackupCodec` export + restore.
- `CollectionStore` (replace/append/clear) builds models from drafts.
- `DemoLoader` loads the bundled `Resources/*.csv` through the real import pipeline.
- A minimal **Data** toolbar menu on both tabs: import (replace/append), export CSV, full
  backup, restore, sample data, clear all.
- Swift Testing suites for CSV, import, backup sanitizer, and apply.

Each source file cites the web module it mirrors.
