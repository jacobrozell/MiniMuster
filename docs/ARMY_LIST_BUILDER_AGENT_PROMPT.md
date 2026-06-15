# Agent prompt — Muster tab implementation

Copy everything inside the block below into a **new Cursor agent chat** (Agent mode). The agent should run until Phase 1 **and** Phase 2 acceptance criteria in [ARMY_LIST_BUILDER_IMPL.md](ARMY_LIST_BUILDER_IMPL.md) are met.

---

## Prompt (copy from here)

```
Implement the MiniMuster **Muster tab** (army list builder) on a new git branch. Work autonomously until Phase 1 and Phase 2 are complete and verified. Do not ask for confirmation between steps unless blocked.

## Repository

- Path: `/Users/jrozell/Desktop/personal/WarhammerTracker/ios`
- App: MiniMuster — Swift 6, SwiftUI, SwiftData, iOS 18+
- Xcode project is generated: run `xcodegen generate` from `ios/` whenever you add/move Swift files.

## Authoritative specs (read first)

1. **Implementation guide (primary):** `docs/ARMY_LIST_BUILDER_IMPL.md` — file tree, code sketches, tests, acceptance criteria, checklist order.
2. **Product/UX context:** `docs/ARMY_LIST_BUILDER.md`
3. **Patterns to match:** `MiniMuster/Features/Armies/ArmyStore.swift`, `MiniMuster/Features/Collection/CollectionTab.swift`, `MiniMuster/Features/Armies/ArmySheets.swift`, `MiniMusterTests/PhotoStoreTests.swift`, `MiniMusterTests/TestSupport.swift`

Follow the implementation checklist in IMPL **top to bottom**. Phase 1 fully before Phase 2.

## Git

1. From `ios/`, create branch: `feature/muster-tab`
2. Do **not** push or open a PR unless I ask.
3. Do **not** commit unless I ask — but keep the branch ready with a clean working tree when done (or one logical commit if I later ask).

## Scope

**In scope (must ship):**
- Phase 1: `Roster` / `RosterEntry`, unit catalog JSON, Muster tab UI, points bar, text share, deep links
- Phase 2: `CollectionMatcher`, fieldable %, add missing to collection, cross-tab navigation basics

**Out of scope:**
- BattleScribe import, wargear options, detachment validation rules
- Backup v5 (optional; skip unless trivial)
- App Store screenshots / onboarding page 5 (skip unless time remains)
- Cloud sync, push notifications, barcode scanner

## Implementation rules

- Match existing naming, `@MainActor` stores, SwiftData patterns, and design system (`CrestBadge`, `ProgressView`, form sheets).
- `Roster` ≠ collection `Army` — never conflate types.
- Bundle catalog under `MiniMuster/Resources/UnitCatalog/` — fully populate `40k/grey-knights.json` (≥7 units); stub other faction files with `"units": []` is OK for build, but add at least 5 real units each if tests need them.
- Register `Roster.self`, `RosterEntry.self` in `AppContainer.schema`.
- Third tab in `RootView`: **Collection · Muster · Paints** — `flag.fill`, accessibility id `tabMuster`.
- Extend `AppRouter.Tab` with `.muster` and navigation helpers per IMPL.

## Verify with XcodeBuildMCP (required loop)

Use **XcodeBuildMCP** MCP tools — not raw `xcodebuild` unless MCP fails.

### Session setup (first action)

1. Call `session_show_defaults`.
2. If project/scheme/simulator missing, call `session_set_defaults` with:
   - `projectPath`: `/Users/jrozell/Desktop/personal/WarhammerTracker/ios/MiniMuster.xcodeproj`
   - `scheme`: `MiniMuster`
   - `simulatorName`: `iPhone 17` (or latest iPhone simulator available)
3. Run `xcodegen generate` in `ios/` via shell before first build if `.xcodeproj` is stale or missing files.

### After each meaningful chunk (or any compile error)

1. `build_sim` — must succeed with zero errors.
2. Fix all compiler errors before continuing.

### Before declaring done

1. `test_sim` with focus on new tests:
   - `MiniMusterTests/UnitCatalogTests`
   - `MiniMusterTests/RosterPointsTests`
   - `MiniMusterTests/RosterStoreTests`
   - `MiniMusterTests/UnitNameMatchTests`
   - `MiniMusterTests/CollectionMatcherTests`
2. Then full `MiniMusterTests` suite — all existing tests must still pass.
3. `build_run_sim` — app launches without crash on cold start.
4. Manually sanity-check in simulator if MCP UI tools available: tap `tabMuster`, create Grey Knights Strike Force list, add Interceptor Squad, confirm points bar shows 95.

### Iteration protocol

When build or tests fail:
1. Read MCP `diagnostics.errors` / `testFailures` — fix root cause, not symptoms.
2. Re-run the **same** MCP command that failed.
3. Do not stop with failing tests or build errors.
4. If bundle JSON not found at runtime, add/fix `UnitCatalogTests` and verify subdirectory path in `UnitCatalogLoader`.

## Definition of done

All items in **Acceptance criteria (Phase 1 done when)** and **Acceptance criteria (Phase 2 done when)** in `docs/ARMY_LIST_BUILDER_IMPL.md` are checked.

Additionally:
- [ ] `xcodegen generate` succeeds
- [ ] `build_sim` succeeds
- [ ] All `MiniMusterTests` pass via `test_sim`
- [ ] `build_run_sim` launches app
- [ ] No new linter issues in touched Swift files
- [ ] IMPLEMENTATION checklist in IMPL doc mentally complete (steps 1–19)

## Final handoff message

When finished, reply with:
1. Branch name
2. Summary of files created/modified (grouped)
3. Test results (pass counts)
4. Anything deferred or known limitations
5. Suggested commit message (do not commit unless I ask)

Do not stop early. Continue until definition of done is satisfied or you hit a blocker that requires human input (signing, Apple Developer portal, missing secrets).
```

---

## Notes for the human

- Paste the prompt into a **fresh agent** with MCP enabled (`project-0-ios-XcodeBuildMCP`).
- Ensure `MiniMuster.xcodeproj` exists locally (`xcodegen generate`).
- The agent may run 30–90 minutes for full Phase 1+2.
- After completion, review diff on `feature/muster-tab` before merge.

## Changelog

| Date | Notes |
|------|-------|
| 2026-06-15 | Initial agent prompt for Muster tab |
