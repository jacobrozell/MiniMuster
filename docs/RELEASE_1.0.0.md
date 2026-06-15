# Release plan — MiniMuster iOS 1.0.0

**Goal:** Ship a production-ready 1.0.0 on the App Store — trustworthy, native, and verified.

**Status:** In progress — Track B largely complete; app icon, store assets, and submission prep underway.

**Related specs:** [`docs/ios-native/11-roadmap-and-acceptance.md`](../../docs/ios-native/11-roadmap-and-acceptance.md) · [`PRIVACY.md`](PRIVACY.md) · [`BARCODE_SCANNER.md`](BARCODE_SCANNER.md) _(future)_

---

## Summary

| Track | Items | Purpose |
|-------|-------|---------|
| **A — Ship blockers** | 6 | App Store submission requirements |
| **B — High-value polish** | 7 | “Feels finished” without new domain features |
| **C — Accessibility spot-check** | 4 | HIG / spec DoD before tag |
| **Deferred (1.0.1+)** | — | Sync, photos, Shortcuts, barcode scan, etc. |

**Active focus:** Track A (App Store blockers) + remaining Track C device verification.

---

## Track A — Ship blockers (App Store)

Do not submit until these are done.

- [x] **App icon** — MM crest shield in `Assets.xcassets` / AppIcon (1024×1024, universal + dark + tinted).
- [ ] **Screenshots (5–6)** — Run `./scripts/capture-app-store-screenshots.sh`; upload from `.app-store-screenshots/`. See [`docs/APP_STORE.md`](APP_STORE.md).
- [ ] **Hosted privacy policy URL** — `docs/privacy.html` ready; enable GitHub Pages (`/docs`) → `https://jacobrozell.github.io/MiniMuster/privacy.html`.

- [ ] **Manual regression** — Run checklist below (from native spec §4).  
  _Deliverable:_ All 10 steps pass on iPhone + iPad.

- [ ] **TestFlight** — Build on SE/small phone, Pro, iPad; default + Large text.  
  _Deliverable:_ No layout blockers; no crash on cold launch.

- [ ] **App Store metadata** — Draft in [`docs/APP_STORE.md`](APP_STORE.md); paste into App Store Connect.

---

## Track B — High-value polish (implement next)

These are small, high-impact items. **Knock all of these before tagging 1.0.0.**

### B1. First-launch onboarding

**Status:** ✅ Implemented (`OnboardingView`, `RootView`, `hasSeenOnboarding`).

**Acceptance:**
- [x] Fresh install (`UI-Testing` or delete app) shows sheet once.
- [x] Second launch does not show sheet (`testOnboardingNotShownAfterRelaunch`).
- [x] Buttons navigate to sample load or Settings as advertised.

---

### B2. Haptics beyond advance

**Status:** ✅ Implemented

- [x] Advance unit/member — existing
- [x] Delete confirmed — army/unit/batch delete
- [x] Duplicate — unit swipe/context/toolbar
- [x] Filter applied (source link) — collection + paints
- [x] Import completed / failed — Settings data section

---

### B3. Move unit from army list

**Status:** ✅ Implemented

**Acceptance:**
- [x] Context menu shows Move to… when ≥2 armies exist.
- [x] Unit appears in destination army; selection clears if moved unit was selected.

---

### B4. Army row context menu

**Status:** ✅ Implemented

**Acceptance:**
- [x] Rename updates list without navigation.
- [x] Delete shows confirmation; clears selection if deleted army was selected.

---

### B5. Widget refresh on all data changes

**Status:** ✅ Implemented

- `WidgetUpdater.refresh(context:)` central helper
- Refresh after import, restore, sample load, clear all
- `RootView` `widgetSignature` tracks sprue/total model counts (not just row counts)

**Acceptance:**
- [x] Widget updates after import/advance/delete paths that change model counts

---

### B6. Error surfacing on import / restore

**Status:** ✅ Implemented

- Failures → native `.alert` with message
- Success without warnings → banner
- Success with warnings → `ImportResultsSheet`
- `restoreBackupOutcome` / `loadSampleOutcome` helpers

**Acceptance:**
- [x] Invalid CSV / corrupt backup → alert
- [x] Success still uses banner or results sheet

---

### B7. Version in About

**Status:** ✅ Done — `Bundle.appVersion` in Settings → About.

- [x] Verify version matches `MARKETING_VERSION` in `project.yml` at release tag time (`1.0.0`).

---

## Track B — Suggested implementation order

```
1. B6  Import/restore error alerts     (trust)
2. B5  Widget refresh completeness     (small, isolated)
3. B2  Haptics                       (touch many files, mechanical)
4. B4  Army context menu             (quick)
5. B3  Move unit from army list       (reuse existing sheet)
6. B1  Onboarding sheet              (user-facing capstone)
7. B7  Version check at tag          (trivial)
```

Estimate: **2–4 focused sessions** for all of Track B.

---

## Track C — Accessibility spot-check (before tag)

Not new features — verification pass. Code-side fixes applied; device verification still required.

- [x] **Dynamic Type AX5** — Stat grid single column at AX5+; overview headline wraps; rows use semantic type (verify on device).
- [x] **VoiceOver labels** — Undo hint, state picker value, squad member summary, swipe action labels, overview progress.
- [x] **Reduce Motion** — Banner transition gated; ProgressRing gauge animation gated.
- [ ] **iPad split view** — Sidebar army → content units → detail unit (manual verify).

Reference: [`docs/ios-native/09-ipad-and-accessibility.md`](../../docs/ios-native/09-ipad-and-accessibility.md).

---

## Manual regression checklist (Track A)

Run on **iPhone** and **iPad** before submission:

1. Load sample data from Settings
2. Search `ogors` → finds Rat Ogors
3. Filter WIP quick view → correct subset
4. Swipe advance unit → state changes; overview meter updates
5. Undo → restores state
6. Export armies CSV → re-import append
7. Full backup → clear → restore
8. Paint source tap → collection filtered
9. Per-army custom pipeline → advance uses custom stages
10. iPad: select army in sidebar → units in content column

---

## Explicitly deferred (post–1.0.0)

| Feature | Target |
|---------|--------|
| CloudKit / iCloud sync | 1.1+ |
| Unit photos | 1.1+ |
| App Intents / Shortcuts | 1.1+ |
| Extra widgets / Live Activities | 1.1+ |
| Army drag-reorder | 1.0.1 |
| Paint edit-mode batch | 1.0.1 |
| Crash reporting (MetricKit) | Optional anytime |
| GW barcode scan & box import | 1.2+ — spec: [`BARCODE_SCANNER.md`](BARCODE_SCANNER.md) |

---

## Release checklist (final tag)

- [x] Track B complete — B1–B7 done; final device pass for C
- [ ] Track C spot-check done
- [ ] Track A blockers done
- [ ] `MARKETING_VERSION` = `1.0.0` in `project.yml`
- [ ] Unit tests (62+) green in CI
- [ ] UI smoke tests (3) green in CI
- [ ] Git tag `ios/1.0.0` or `v1.0.0`
- [ ] App Store submission

---

## Changelog stub (for App Store / tag notes)

**MiniMuster 1.0.0**

- Native collection browser with search, filters, and overview stats
- Unit detail editing, swipe advance, and batch select in armies
- Paint inventory with list/grid and collection deep links
- Import/export and full backup compatible with the web app
- Local-first: your data stays on device
- Home screen widget: models on the sprue
- iPad split-view support
