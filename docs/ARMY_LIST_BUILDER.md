# Spec — Army list builder (Muster tab)

Verbose implementation plan for a **basic army list generator** — New Recruit–inspired UI and workflow, integrated with MiniMuster’s collection tracker as a **third core tab: Muster**.

**Status:** Future release — spec only (not scheduled)  
**Target:** 1.2+ (after photos + cloud sync foundations); MVP may ship as **1.2 “Muster”**  
**App:** MiniMuster (iOS)

### Why “Muster” (not “Lists”)

| | **Lists** (NR default) | **Muster** (our tab) |
|--|------------------------|----------------------|
| Brand | Generic | Matches **MiniMuster** — the app is literally about mustering |
| Lore | Spreadsheet energy | *Muster your army* — 40k/AoS vocabulary players already use |
| Tab trio | Collection · Lists · Paints | **Collection · Muster · Paints** — three distinct verbs |
| Confusion | “Lists” vs list views in Collection | **Muster** = tabletop rosters only; Collection = painting inventory |

NR users still get familiar **flows** (saved rosters, points bar, unit browser); only the **tab label** and home nav title change. In-app copy can still say “list” and “roster” where precise.

> **Product thesis:** New Recruit answers *“What can I bring to the table?”* MiniMuster answers *“What do I still need to paint?”* Combining both in one local-first app is the killer wedge — list building that knows your shelf.

**See also:** [ARMY_LIST_BUILDER_IMPL.md](ARMY_LIST_BUILDER_IMPL.md) — **agent handoff** (files, code, tests) · [BARCODE_SCANNER.md](BARCODE_SCANNER.md) · [CLOUD_SYNC.md](CLOUD_SYNC.md) · [POLISH_IDEAS.md](POLISH_IDEAS.md) · [ROADMAP.md](ROADMAP.md)

**Reference app:** [New Recruit](https://www.newrecruit.eu/) — army list builder for 40k, AoS, The Old World, etc. We are **not** cloning tournaments, play mode, or BattleScribe import in v1; we **are** adopting the list-creation UX patterns users already love.

---

## Goals

1. Let players **draft rosters** with automatic point totals and battle-size targets — without leaving MiniMuster.
2. **Bridge lists ↔ collection** — instantly see which list units you own, which you need to buy/build, and push missing entries into a painting army.
3. Ship as a **first-class tab** (not a buried Settings action) so list building feels as important as tracking paint.
4. Stay **offline-first** — unit/points catalog bundled; optional catalog updates like the barcode product catalog.
5. Reuse existing **faction catalogue** (`FactionDefs`, `FactionResolver`) for crests, colours, and picker consistency.

## Non-goals (v1 / “basic”)

| Out of scope | Why |
|--------------|-----|
| Full BattleScribe rules engine | Months of maintenance; NR uses community BS datasets |
| Tournament org, ELO, pairings | Different product |
| Play mode / game assistant / CP tracking | NR subscriber feature; table play is separate |
| Wargear option trees (multi-hand weapons, nested upgrades) | Phase 3+; MVP is named unit + qty + base points |
| Detachment / force-org **validation** | Soft warnings only in MVP; hard validation Phase 3 |
| BattleScribe `.ros` import | Phase 4 |
| Online list sharing / NR sync | Local-first; [CLOUD_SYNC.md](CLOUD_SYNC.md) for own devices |
| Official GW API | None exists |
| Points as legal truth | Community data + disclaimer |

---

## User stories

| As a… | I want to… | So that… |
|-------|------------|----------|
| New player | Pick faction + battle size and tap units | I can build a 1000 pt list without spreadsheets |
| Collector | See which list units I already own | I know if the list is fieldable today |
| Painter | Add missing units to my collection army | One tap from list → painting pipeline |
| Theorycrafter | Save multiple lists per faction | I can compare builds before buying models |
| Shopper | See “need to buy” summary | I know what a new box/list still requires |
| Returning user | Open Muster tab — NR-like flows, on-brand name | Feels native to MiniMuster, not a clone |

---

## New Recruit UX — what we’re adopting

New Recruit’s builder flow (observed patterns, not a verbatim copy):

```text
┌─────────────────────────────────────────────────────────────┐
│  Muster home         │  Saved rosters, + New muster         │
├──────────────────────┼──────────────────────────────────────┤
│  New list wizard     │  Game → Faction → Battle size/name   │
├──────────────────────┼──────────────────────────────────────┤
│  List editor         │  Faction header, pts used/limit bar  │
│                      │  Scrollable unit rows (qty, pts)     │
│                      │  FAB / toolbar → Add unit            │
├──────────────────────┼──────────────────────────────────────┤
│  Unit browser        │  Search, category filters, tap add   │
├──────────────────────┼──────────────────────────────────────┤
│  Collection link     │  NR: “playable / need to buy”        │
│  (our differentiator)│  We deepen this + painting state     │
└─────────────────────────────────────────────────────────────┘
```

**NR patterns to mirror in SwiftUI**

| Pattern | MiniMuster implementation |
|---------|---------------------------|
| Persistent **Muster** home | `MusterTab` → `MusterHomeView` |
| **Points footer** always visible | `safeAreaInset(edge: .bottom)` sticky bar |
| **Battle size** presets (Incursion / Strike Force / …) | `BattleSize` enum per game |
| **Faction crest + colour** in list header | Reuse `FactionResolver` + `BrandCrest` |
| **Search-first** unit picker | `.searchable` on catalog browser |
| **Qty stepper** on list rows | Same as `AddUnitSheet` / unit detail |
| Swipe delete row | Standard `List` swipe actions |
| Duplicate list | Context menu like unit duplicate |
| Over-points shown in **red** | Soft warning; no block in MVP |

**NR patterns we defer**

- Ads / subscription gates  
- Play mode lock + datasheet overlay  
- Global tournament stats  
- BattleScribe ROS import (Phase 4)  
- Presets system (Phase 2 — save default battle size per game)

---

## Tab shell integration

### Today

```swift
// RootView.swift — two tabs
TabView {
  CollectionTab()   // shield
  PaintsTab()       // paintpalette
}
```

### Target

```swift
TabView {
  CollectionTab()   // shield.lefthalf.filled — "Collection"
  MusterTab()       // flag.fill — "Muster"  ← NEW
  PaintsTab()       // paintpalette.fill — "Paints"
}
```

**Symbol:** `flag.fill` (rally the army) or `person.3.fill` (troops gathering). Prefer **`flag.fill`** — distinct from Collection’s shield at a glance.

**`AppRouter` additions**

```swift
enum Tab: String { case armies, muster, paints }

// Muster tab state
var musterSearch: String = ""
var pendingRosterId: UUID?            // deep link open roster
var pendingCollectionLink: UUID?      // highlight collection army linked to roster
```

**Accessibility:** `tabMuster` on the tab label.

**Badge:** Muster tab badge = count of saved rosters (optional).

**iPad:** `NavigationSplitView` in `MusterTab` — sidebar roster list → roster editor → optional unit picker column in regular width.

**Onboarding:** Add one onboarding page (or Tips) — *Muster lists for the table, track painting in Collection — see what you can field before game day.*

---

## Architecture overview

```text
┌─────────────────────────────────────────────────────────────┐
│  SwiftUI — MusterTab, RosterEditorView, UnitCatalogBrowser, … │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│  RosterStore — CRUD, point totals, collection matching      │
└─────────────┬─────────────────────────────┬─────────────────┘
              │                             │
┌─────────────▼──────────────┐   ┌──────────▼──────────────────┐
│  SwiftData                  │   │  UnitCatalog (bundle JSON) │
│  Roster, RosterEntry        │   │  Faction units + points    │
└─────────────┬──────────────┘   └────────────────────────────┘
              │
┌─────────────▼──────────────────────────────────────────────┐
│  Collection (existing Army, Unit) — fuzzy match + import    │
└────────────────────────────────────────────────────────────┘
```

**Principles**

- **`Roster` ≠ `Army`.** Collection armies track painting; rosters track tabletop points. Link optionally via `linkedArmyId`.
- **Catalog is read-only** at runtime (bundled JSON). Mutations only to user rosters.
- **Points are cached** on `RosterEntry` at add time; recalculate when catalog version bumps with migration banner.
- **Matching is fuzzy** — reuse `SourceMatch` / normalized unit names from paints linking.

---

## Data model

### `Roster`

SwiftData model — syncable when [CLOUD_SYNC.md](CLOUD_SYNC.md) lands.

```swift
import Foundation
import SwiftData

/// A saved army list for tabletop play (not a painting collection army).
@Model
final class Roster {
    var id: UUID = UUID()
    var name: String = ""
    var game: String = "40k"
    var faction: String = ""
    /// Battle size key, e.g. "strike-force" → 2000 pts for 40k 10e.
    var battleSizeKey: String = "strike-force"
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sortIndex: Int = 0

    /// Optional link to a collection Army for ownership + painting context.
    var linkedArmyId: UUID?

    /// Catalog bundle version at last edit (for stale-points warnings).
    var catalogVersion: String = ""

    @Relationship(deleteRule: .cascade, inverse: \RosterEntry.roster)
    var entries: [RosterEntry] = []

    init(name: String, game: String, faction: String, battleSizeKey: String) {
        self.name = name
        self.game = game
        self.faction = faction
        self.battleSizeKey = battleSizeKey
    }
}
```

### `RosterEntry`

```swift
@Model
final class RosterEntry {
    var id: UUID = UUID()
    /// Stable id in UnitCatalog, e.g. "40k:grey-knights:interceptor-squad".
    var catalogUnitId: String = ""
  var displayName: String = ""      // denormalized for display if catalog changes
    var qty: Int = 1
    var pointsEach: Int = 0         // base points at add time
    var sortIndex: Int = 0

    /// Phase 3: JSON blob of selected wargear option ids → extra points.
    var wargearSelectionJSON: String?

    var roster: Roster?

    var pointsTotal: Int { qty * pointsEach + (wargearExtraPoints ?? 0) }
    var wargearExtraPoints: Int?    // Phase 3
}
```

### `BattleSize` (domain, not persisted per row)

```swift
struct BattleSize: Identifiable, Hashable, Codable {
    let id: String           // "incursion", "strike-force", "onslaught"
    let label: String        // "Incursion"
    let pointsLimit: Int     // 1000, 2000, 3000
    let game: String         // "40k"
}

enum BattleSizes {
    static let warhammer40k: [BattleSize] = [
        .init(id: "incursion", label: "Incursion", pointsLimit: 1000, game: "40k"),
        .init(id: "strike-force", label: "Strike Force", pointsLimit: 2000, game: "40k"),
        .init(id: "onslaught", label: "Onslaught", pointsLimit: 3000, game: "40k"),
        .init(id: "custom", label: "Custom", pointsLimit: 0, game: "40k"), // user override
    ]
    // AoS: 1000 / 2000 / 2500 — Phase 2
}
```

### Limits (`Limits.swift`)

```swift
static let maxRosters           = 64
static let maxEntriesPerRoster  = 128
static let maxCatalogUnits      = 12_000   // guard load
```

---

## Unit catalog (bundled data)

### Layout

```text
MiniMuster/Resources/UnitCatalog/
  manifest.json           # version, games, generation date, attribution
  40k/
    grey-knights.json
    space-marines.json
    … (per faction file)
  aos/                    # Phase 2
    stormcast-eternals.json
  index.json              # faction → file path, unit count
```

Target MVP: **40k only**, **3–5 factions** (e.g. Grey Knights, Space Marines, Necrons, Orks, Chaos Space Marines), **~40–80 units each**, base points only.

### Unit record schema

```json
{
  "id": "40k:grey-knights:interceptor-squad",
  "name": "Interceptor Squad",
  "faction": "Grey Knights",
  "game": "40k",
  "category": "Battleline",
  "basePoints": 95,
  "modelCount": 5,
  "keywords": ["Infantry", "Fly", "Psykic"],
  "aliases": ["Interceptors", "GK Interceptors"],
  "boxSources": ["Grey Knights Combat Patrol"],
  "edition": "10th",
  "pointsKey": "2025-06"
}
```

### Data sourcing & legal

| Source | Use |
|--------|-----|
| [BSData](https://github.com/BSData) community catalogs | Starting point for unit names + points (verify per release) |
| Wahapedia | Cross-check names; **do not** scrape/store GW copyrighted rules text |
| Manual curation | Combat Patrol units, common tournament staples |

**In-app disclaimer (Settings → Muster or first catalog open):**

> Unit names and points values are unofficial community data for personal list building. Not endorsed by Games Workshop. Verify before events.

Same posture as [BARCODE_SCANNER.md](BARCODE_SCANNER.md) § legal — factual names + numbers for personal use.

### Catalog updates

Mirror barcode catalog strategy:

- Bump `manifest.json` version quarterly  
- Optional download from GitHub releases (Settings → Muster → Check for catalog update)  
- On version change: banner *Points may have changed — review open lists*

---

## Domain logic

### `RosterPoints`

```swift
enum RosterPoints {
    static func total(entries: [RosterEntry]) -> Int {
        entries.reduce(0) { $0 + $1.pointsTotal }
    }

    static func remaining(limit: Int, entries: [RosterEntry]) -> Int {
        limit - total(entries: entries)
    }

    static func isOverLimit(limit: Int, entries: [RosterEntry]) -> Bool {
        limit > 0 && total(entries: entries) > limit
    }
}
```

### `CollectionMatch` (killer feature)

Match roster entries against collection `Unit` rows (all armies or linked army only).

```swift
struct CollectionMatchResult: Sendable {
    enum Status { case owned, partial, missing, unknown }
    let entryId: UUID
    let status: Status
    let ownedQty: Int          // matched model count
    let requiredQty: Int       // entry.qty * catalog.modelCount
    let matchedUnitIds: [UUID]
}

enum CollectionMatcher {
    /// Fuzzy match: normalize names, strip parenthetical counts, alias table.
    static func match(
        entry: RosterEntry,
        catalogUnit: CatalogUnit?,
        collectionUnits: [Unit]
    ) -> CollectionMatchResult

    static func fieldablePercent(entries: [RosterEntry], results: [CollectionMatchResult]) -> Int
}
```

**UI semantics (NR-inspired)**

| Status | Row badge | Meaning |
|--------|-----------|---------|
| Owned | Green check | Enough painted/unpainted models in collection |
| Partial | Amber dash | Some qty, not enough |
| Missing | Red plus | Not in collection |
| Unknown | Gray ? | Custom entry / catalog id missing |

**Actions**

- **Add missing to collection** → `ArmyStore.addUnit` on linked army (or picker) with `source` = roster name  
- **Link to army** → set `roster.linkedArmyId`  
- **View in collection** → `AppRouter` jump to unit detail

Reuse paint-tab **source link** patterns (`SourceMatch`) for name normalization.

---

## Cross-tab navigation

Muster only wins if Collection and Muster feel like one app, not two bolted together.

### Collection → Muster

| Trigger | Action |
|---------|--------|
| Army detail toolbar | **Muster roster…** — create new roster pre-filled with faction/game, or open linked roster |
| Unit detail toolbar | **Add to muster** — if catalog match exists, picker of rosters for that faction |
| Overview | *Fieldable lists* row (Phase 2) — rosters where fieldable % &gt; 0 |

### Muster → Collection

| Trigger | Action |
|---------|--------|
| Roster editor · linked army chip | Tap → `AppRouter.tab = .armies`, select army |
| Entry row · owned badge | Tap → unit detail for first matched `Unit` |
| Entry row · missing badge | **Add to collection** inline |
| Roster toolbar | **Add all missing** batch |

### Paints → Muster (Phase 2+)

| Trigger | Action |
|---------|--------|
| Paint source link | Unchanged — filters Collection; optional banner *Also used in 2 muster lists* |

### `AppRouter` coordination

```swift
extension AppRouter {
    func openMuster(rosterId: UUID) {
        pendingRosterId = rosterId
        tab = .muster
    }

    func openCollection(armyId: UUID, unitId: UUID? = nil) {
        selectedArmyId = armyId
        selectedUnitId = unitId
        tab = .armies
    }

    func createRoster(from army: Army, battleSizeKey: String, in ctx: ModelContext) throws -> Roster {
        // Pre-fill game, faction, linkedArmyId; navigate to editor
    }
}
```

iPad: cross-tab jumps preserve split-view selection in each tab’s `NavigationSplitView`.

---

## Deep links

Extend [`AppDeepLink`](../MiniMuster/Support/AppDeepLink.swift):

| URL | Behavior |
|-----|----------|
| `minimuster://muster` | Muster home |
| `minimuster://muster/{uuid}` | Open roster editor |
| `minimuster://muster/new?game=40k&faction=Grey%20Knights` | New roster sheet pre-filled |
| `minimuster://collection/backlog` | Existing widget link |

Widget (Phase 4): tap opens `minimuster://muster/{lastEditedRosterId}`.

Push notification ([PUSH_NOTIFICATIONS.md](PUSH_NOTIFICATIONS.md)) Phase 3 candidate:

- *Your Grey Knights list is 100% fieldable* → `minimuster://muster/{id}`

---

## Onboarding (when Muster ships)

Add **page 5** to [`OnboardingView`](../MiniMuster/Features/Onboarding/OnboardingView.swift) — only for installs that upgrade to 1.2+ with `hasSeenOnboarding == true`, use a one-time `hasSeenMusterIntro` flag instead of re-running full onboarding.

```swift
Page(
    id: 4,
    symbol: "flag.fill",
    title: "Muster for the table",
    subtitle: "Lists that know your shelf",
    body: "Build point lists in the Muster tab. See which units you already own in Collection and send missing models straight to your painting army."
)
```

**TipKit:** `MusterTabTip` on first visit to Muster tab — *Tap + to muster a new list*.

---

## iPad layout (`MusterTab`)

```text
Regular horizontal size class:

┌──────────────┬─────────────────────┬──────────────────┐
│ Rosters      │ Roster editor       │ Unit catalog     │
│ (sidebar)    │ (content)           │ (inspector,      │
│              │                     │  optional col)   │
└──────────────┴─────────────────────┴──────────────────┘

Compact / portrait phone:

MusterHome → push RosterEditor → sheet UnitCatalogBrowser
```

Reuse `AdaptiveLayout.usesSidebarListStyle` patterns from `CollectionTab`.

---

## MVP catalog scope (Phase 1)

Ship one game, five factions, ~50 units each — enough for credible Strike Force lists.

| Faction | Rationale |
|---------|-----------|
| Grey Knights | Sample data faction; combat patrol in barcode spec |
| Space Marines | Largest player base |
| Necrons | Popular, distinct roster shape |
| Orks | Troop-heavy, good stress test for qty |
| Chaos Space Marines | Second imperium-adjacent staple |

**Per faction file:** `40k/grey-knights.json` — see schema § Unit catalog.

**Validation before ship:** Each faction has at least one HQ, two Battleline, one vehicle; manual 2000 pt list buildable without custom entries.

---

## Settings additions

**Settings → Muster** (new section when tab ships)

| Row | Purpose |
|-----|---------|
| Catalog version | `manifest.json` version + date |
| Check for updates | Optional network fetch |
| Default battle size | Per-game preset for new rosters |
| Disclaimer | Link to unofficial data notice |
| Reset muster intro | Clears `hasSeenMusterIntro` |

Global pipeline and faction crest editors stay under **Painting** — rosters read those for display only.

---

## UI plan

### Phase 1 — Muster tab MVP (“basic army generation”)

#### `MusterHomeView`

- Navigation title: **Muster** (tab label matches).
- Empty state: *Muster an army list — count points, see what you can field.*
- `List` of rosters: name, faction crest, `945 / 2000 pts`, fieldable % (Phase 2: hide until linked)
- Toolbar: `+` → `NewRosterSheet` (sheet title: **New muster** or **New list** — “list” is fine in forms)
- Context menu: Duplicate, Rename, Delete
- Search rosters by name/faction

#### `NewRosterSheet`

Mirrors NR new-list wizard:

1. **Game** — Picker: `40k` only in MVP  
2. **Faction** — Reuse `FactionResolver.canonicalByGame`  
3. **Battle size** — Segmented or picker from `BattleSizes`  
4. **Name** — Default: `"\(faction) \(battleSize.label)"`  
5. **Link collection army** — Optional picker of existing armies matching game+faction  

#### `RosterEditorView`

```text
┌────────────────────────────────────────┐
│  ← Grey Knights 2000pt        ⋯        │
│  [GK crest]  Strike Force              │
│  ████████████░░░░░░  945 / 2000 pts    │
├────────────────────────────────────────┤
│  Interceptor Squad          95 pts  −+ │
│  5 models · Battleline                 │
├────────────────────────────────────────┤
│  Nemesis Dreadknight         210 pts −+│
│  ...                                   │
├────────────────────────────────────────┤
│  [ + Add unit ]                        │
└────────────────────────────────────────┘
```

- Sticky bottom bar: points total, remaining, over-limit tint  
- Toolbar: Rename, Duplicate, Share (text export), Link army, Delete list  
- Swipe delete entry  
- Tap row → `RosterEntrySheet` (qty stepper, remove, Phase 3 wargear)

#### `UnitCatalogBrowser`

Presented as sheet or iPad third column:

- `.searchable` — name, keyword, alias  
- Section by `category` (HQ, Battleline, Other)  
- Row: name, points, category chip  
- Tap → add with qty 1; repeat tap increments qty if already in list  
- Filter: show only units with `boxSources` containing … (Phase 2)

#### Share export (MVP text)

```
Grey Knights — Strike Force (2000 pts)
Total: 945 pts

• Interceptor Squad — 95 pts
• Nemesis Dreadknight — 210 pts
…

Built with MiniMuster (unofficial list)
```

Phase 2: `ImageRenderer` pretty export (NR “Pretty Export” inspired).

### Phase 2 — Collection bridge

- [ ] Fieldable % on list row + editor header  
- [ ] Per-entry ownership badges via `CollectionMatcher`  
- [ ] **Add all missing** batch → linked army  
- [ ] Highlight painting state: *owned but still on sprue* (collection `state`)  
- [ ] Deep link: Collection unit → *Add to list* if catalog match exists  
- [ ] Default battle size preset per game in Settings  

### Phase 3 — Validation lite

- [ ] Category counts: HQ max, Battleline min (40k 10e simplified table)  
- [ ] Warning chips in editor — soft, not blocking  
- [ ] `Detachment` picker (fixed set per faction, no full rules)  
- [ ] Simple wargear: +pts toggles on entry sheet from catalog `options[]`  

### Phase 4 — Parity extras

- [ ] BattleScribe `.ros` / New Recruit import (lossy)  
- [ ] AoS + The Old World catalog files  
- [ ] Catalog CDN auto-update  
- [ ] Widget: “Next list” points summary (stretch)  

---

## `RosterStore`

```swift
@MainActor
enum RosterStore {
    static func addRoster(name: String, game: String, faction: String,
                          battleSizeKey: String, linkedArmyId: UUID?,
                          in ctx: ModelContext) throws -> Roster

    static func addEntry(from catalogUnit: CatalogUnit, qty: Int = 1,
                         to roster: Roster, in ctx: ModelContext) throws -> RosterEntry

    static func setQty(_ entry: RosterEntry, _ qty: Int, in ctx: ModelContext)
    static func delete(_ entry: RosterEntry, in ctx: ModelContext)
    static func delete(_ roster: Roster, in ctx: ModelContext)

    static func duplicate(_ roster: Roster, in ctx: ModelContext) throws -> Roster

    /// Push missing catalog units into linked Army as collection Unit rows.
    static func importMissingToCollection(roster: Roster,
                                          matches: [CollectionMatchResult],
                                          in ctx: ModelContext) throws -> Int
}
```

Undo hooks: integrate with `UndoService` for entry delete and qty changes (match army unit patterns).

---

## Backup & interchange

### JSON backup v5 (future)

Extend `Snapshot` with optional `rosters` array — does not break web app (unknown keys stripped).

```json
{
  "version": 5,
  "collection": [ "…" ],
  "rosters": [
    {
      "id": "uuid",
      "name": "GK 2000",
      "game": "40k",
      "faction": "Grey Knights",
      "battleSizeKey": "strike-force",
      "linkedArmyId": "uuid-or-null",
      "entries": [
        { "catalogUnitId": "40k:grey-knights:interceptor-squad", "qty": 1, "pointsEach": 95 }
      ]
    }
  ]
}
```

CSV: no roster columns (data-only armies remain separate).

### Barcode scanner synergy

When [BARCODE_SCANNER.md](BARCODE_SCANNER.md) adds a Combat Patrol:

- Scan → add to **collection**  
- Optional: *Also create roster with patrol contents at patrol points?* (Phase 2+)

---

## Accessibility & screenshots

- VoiceOver: list row announces `Interceptor Squad, 95 points, 1 unit, owned`  
- Dynamic Type: points bar wraps; sticky footer uses `minimumScaleFactor`  
- UI test ids: `tabMuster`, `musterAddUnit`, `rosterPointsBar`  
- App Store screenshot: Muster tab with fieldable % — differentiator vs pure trackers  

---

## Testing checklist

- [ ] `RosterPointsTests` — totals, over limit, custom battle size  
- [ ] `CollectionMatcherTests` — exact, alias, parenthetical counts, partial qty  
- [ ] `CatalogLoaderTests` — parse faction file, unknown id graceful  
- [ ] `RosterStoreTests` — add, duplicate, max entries, cascade delete  
- [ ] Backup round-trip v5 with rosters  
- [ ] Manual: build 2000 pt list, link army, add missing, verify collection  
- [ ] Manual: iPad three-column lists flow  

---

## Implementation phases & order

```text
Phase 1  Muster tab + catalog loader + editor + points bar    (core “NR steal”)
Phase 2  CollectionMatcher + link army + add missing          (differentiator)
Phase 3  Validation lite + wargear                            (deeper 40k)
Phase 4  Import/export parity + more games                      (breadth)
```

Suggested build order within Phase 1:

```
1. Catalog JSON schema + CatalogLoader (domain, tests)
2. Roster / RosterEntry models + RosterStore
3. MusterTab + MusterHomeView + NewRosterSheet
4. RosterEditorView + UnitCatalogBrowser + points footer
5. AppRouter tab + RootView three-tab shell
6. Text share export
7. UI tests + screenshot flow
```

Estimate: **3–5 focused sessions** for Phase 1 MVP (one game, three factions).

---

## Open questions

1. ~~**Tab label**~~ — **Resolved: Muster.** In-form copy may still say “list” / “roster”.  
2. **Custom units:** Allow free-text entry with manual points for proxies/unlisted units?  
3. **Edition lock:** Store `edition` on roster when created — warn on catalog bump?  
4. **Points changelog:** Show diff when catalog updates (+5 pts on Dreadnought)?  
5. **Link vs merge:** Should linking a roster **sync** qty changes back to collection or one-way import only?  
6. **Web app:** Port rosters to web MiniMuster later, or iOS-only feature?  
7. **Deep link path:** `minimuster://muster/{rosterId}` — on-brand; confirm vs `…/roster/…`.  

---

## Competitive positioning

| App | Strength | MiniMuster + Muster |
|-----|----------|-------------------|
| New Recruit | Best-in-class builder + validation | Adopt builder UX; defer full validation |
| MiniMuster today | Painting + collection | Adds NR list flow on **Muster** tab |
| Combined | — | **Only app that shows paint progress on list units** |

Marketing line: *Muster for the table. Collection for the bench. Paints for the rack.*

---

## Changelog

| Date | Notes |
|------|-------|
| 2026-06-15 | Initial spec — Lists tab, NR-inspired UX, collection bridge |
| 2026-06-15 | Tab renamed to **Muster** — brand alignment, resolved open question |
| 2026-06-15 | Cross-tab nav, deep links, onboarding page 5, iPad layout, MVP catalog factions |
| 2026-06-15 | Split agent guide → [ARMY_LIST_BUILDER_IMPL.md](ARMY_LIST_BUILDER_IMPL.md) |
