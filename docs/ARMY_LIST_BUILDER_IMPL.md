# Army list builder — agent implementation guide

**Hand this document to an implementation agent.** It contains file paths, code sketches, algorithms, tests, and acceptance criteria for Phase 1–2 of the Muster tab.

**Agent prompt (copy-paste):** [ARMY_LIST_BUILDER_AGENT_PROMPT.md](ARMY_LIST_BUILDER_AGENT_PROMPT.md)

**Product context:** [ARMY_LIST_BUILDER.md](ARMY_LIST_BUILDER.md) · **Sequencing:** [ROADMAP.md](ROADMAP.md) (target **1.2**)

---

## Scope for this guide

| Phase | Ships | Out of scope here |
|-------|-------|-------------------|
| **1** | Muster tab, catalog, roster CRUD, points bar, text export | Wargear, validation rules, BS import |
| **2** | `CollectionMatcher`, fieldable %, add missing, cross-tab | Photos on roster rows, widget |

Implement **Phase 1 completely** before Phase 2. Phase 2 files are listed but marked `(P2)`.

---

## Prerequisites

- iOS 18+, Swift 6, SwiftData — same as app today.
- Run `xcodegen generate` after adding files under `MiniMuster/` (XcodeGen picks up the tree automatically).
- No new Swift packages or entitlements for Phase 1.
- Read patterns in: `ArmyStore.swift`, `CollectionTab.swift`, `AddArmySheet.swift`, `SourceMatch.swift`, `PhotoStoreTests.swift`.

---

## File tree

### Create

```text
MiniMuster/
  Models/
    Roster.swift
    RosterEntry.swift
  Domain/Muster/
    BattleSize.swift
    RosterPoints.swift
    CatalogUnit.swift
    UnitCatalogLoader.swift
    UnitNameMatch.swift
    CollectionMatcher.swift          # (P2)
    RosterExport.swift
  Features/Muster/
    MusterTab.swift
    MusterRoute.swift
    MusterHomeView.swift
    NewRosterSheet.swift
    RosterEditorView.swift
    RosterEntryRow.swift
    RosterEntrySheet.swift
    RosterPointsBar.swift
    UnitCatalogBrowser.swift
    OwnershipBadge.swift             # (P2)
    MusterSettingsSection.swift      # (P2) — or fold into SettingsScreen
  Resources/UnitCatalog/
    manifest.json
    index.json
    40k/grey-knights.json
    40k/space-marines.json           # stub OK for MVP if GK fully populated
    40k/necrons.json                 # stub
    40k/orks.json                    # stub
    40k/chaos-space-marines.json     # stub

MiniMusterTests/
  UnitCatalogTests.swift
  RosterPointsTests.swift
  RosterStoreTests.swift
  UnitNameMatchTests.swift
  CollectionMatcherTests.swift       # (P2)

MiniMusterUITests/
  MusterSmokeUITests.swift           # (optional Phase 1)
```

### Modify

```text
MiniMuster/App/AppContainer.swift       — schema + Roster, RosterEntry
MiniMuster/App/AppRouter.swift          — Tab.muster, navigation helpers
MiniMuster/App/RootView.swift           — third tab, deep link handling
MiniMuster/Support/AppDeepLink.swift    — muster URLs
MiniMuster/Domain/Limits.swift          — roster caps
MiniMuster/Models/AppConfiguration.swift — muster prefs (P2 minimal: hasSeenMusterIntro)
MiniMuster/Features/Settings/SettingsScreen.swift — Muster section (P2)
MiniMuster/DataIO/Backup/Snapshot.swift — v5 rosters (optional Phase 1; required before cloud)
```

---

## Implementation checklist (order)

Copy into PR description; complete top-to-bottom.

### Phase 1

- [ ] **1.** `Limits` — add roster caps  
- [ ] **2.** `CatalogUnit`, `UnitCatalogLoader`, bundle JSON + tests  
- [ ] **3.** `BattleSize`, `RosterPoints`, `RosterExport` + tests  
- [ ] **4.** `Roster`, `RosterEntry` models  
- [ ] **5.** `AppContainer.schema` — register models; verify app launches  
- [ ] **6.** `RosterStore` + tests  
- [ ] **7.** `MusterRoute`, `MusterTab`, `MusterHomeView`, `NewRosterSheet`  
- [ ] **8.** `RosterEditorView`, `RosterEntryRow`, `RosterEntrySheet`, `RosterPointsBar`, `UnitCatalogBrowser`  
- [ ] **9.** `AppRouter` + `RootView` third tab  
- [ ] **10.** `AppDeepLink` muster destinations + `RootView.onOpenURL`  
- [ ] **11.** Text share from roster editor  
- [ ] **12.** UI accessibility identifiers; manual iPhone + iPad pass  

### Phase 2

- [ ] **13.** `UnitNameMatch` + tests  
- [ ] **14.** `CollectionMatcher` + `OwnershipBadge` + tests  
- [ ] **15.** Fieldable % on home + editor; **Add missing to collection**  
- [ ] **16.** `AppRouter.openCollection` / `openMuster` cross-tab  
- [ ] **17.** Army detail toolbar **Muster roster…** (P2)  
- [ ] **18.** `AppConfiguration.hasSeenMusterIntro` + onboarding page  
- [ ] **19.** Settings → Muster disclaimer + catalog version  

---

## Models

### `MiniMuster/Models/Roster.swift`

```swift
import Foundation
import SwiftData

@Model
final class Roster {
    var id: UUID = UUID()
    var name: String = ""
    var game: String = "40k"
    var faction: String = ""
    var battleSizeKey: String = "strike-force"
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sortIndex: Int = 0
    var linkedArmyId: UUID?
    var catalogVersion: String = ""

    @Relationship(deleteRule: .cascade, inverse: \RosterEntry.roster)
    var entries: [RosterEntry] = []

    init(name: String, game: String, faction: String, battleSizeKey: String) {
        self.name = name.capped(Limits.maxStringLen)
        self.game = game
        self.faction = faction
        self.battleSizeKey = battleSizeKey
    }
}

extension Roster {
    var orderedEntries: [RosterEntry] {
        entries.sorted {
            if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func presentation(overrides: [FactionPresetOverride]) -> (crest: String, colorHex: String) {
        FactionResolver.resolve(faction: faction, game: game, overrides: overrides)
    }

    func touch() { updatedAt = Date() }
}
```

### `MiniMuster/Models/RosterEntry.swift`

```swift
import Foundation
import SwiftData

@Model
final class RosterEntry {
    var id: UUID = UUID()
    var catalogUnitId: String = ""
    var displayName: String = ""
    var qty: Int = 1
    var pointsEach: Int = 0
    var sortIndex: Int = 0
    var wargearSelectionJSON: String? = nil  // Phase 3

    var roster: Roster?

    var pointsTotal: Int { qty * pointsEach }

    init(catalogUnitId: String, displayName: String, qty: Int, pointsEach: Int, sortIndex: Int) {
        self.catalogUnitId = catalogUnitId
        self.displayName = displayName.capped(Limits.maxStringLen)
        self.qty = max(1, min(qty, 99))
        self.pointsEach = max(0, pointsEach)
        self.sortIndex = sortIndex
    }
}
```

### `AppContainer.swift` change

```swift
static let schema = Schema([
    Army.self, Unit.self, SquadMember.self, Paint.self, AppConfiguration.self,
    ModelPhoto.self, StageEvent.self,
    Roster.self, RosterEntry.self,
])
```

SwiftData lightweight migration: adding models is automatic for existing installs (new empty tables).

---

## Limits

Add to `MiniMuster/Domain/Limits.swift`:

```swift
static let maxRosters           = 64
static let maxEntriesPerRoster  = 128
static let maxRosterQty         = 99
```

---

## Domain — catalog

### `CatalogUnit.swift` (Sendable struct, not SwiftData)

```swift
struct CatalogUnit: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let faction: String
    let game: String
    let category: String
    let basePoints: Int
    let modelCount: Int
    let keywords: [String]
    let aliases: [String]
    let boxSources: [String]
    let edition: String
    let pointsKey: String
}

struct FactionCatalogFile: Codable {
    let faction: String
    let game: String
    let units: [CatalogUnit]
}

struct UnitCatalogManifest: Codable {
    let version: String
    let generatedAt: String
    let attribution: String
    let games: [String]
}

struct UnitCatalogIndex: Codable {
    /// "40k:Grey Knights" → "40k/grey-knights.json"
    let factions: [String: String]
}
```

### `UnitCatalogLoader.swift`

```swift
enum UnitCatalogLoader {
    private(set) static var manifest: UnitCatalogManifest?
    private static var cache: [String: [CatalogUnit]] = [:]  // faction key → units
    private static var byId: [String: CatalogUnit] = [:]

    /// Call once from MusterTab.onAppear or MiniMusterApp init (idempotent).
    static func loadIfNeeded() {
        guard manifest == nil else { return }
        manifest = decode("manifest", UnitCatalogManifest.self)
        let index = decode("index", UnitCatalogIndex.self)
        for (_, path) in index?.factions ?? [:] {
            let file = decodePath(path, FactionCatalogFile.self)
            let key = factionKey(game: file?.game ?? "", faction: file?.faction ?? "")
            let units = file?.units ?? []
            cache[key] = units
            for u in units { byId[u.id] = u }
        }
    }

    static var version: String { manifest?.version ?? "0" }

    static func units(game: String, faction: String) -> [CatalogUnit] {
        loadIfNeeded()
        return cache[factionKey(game: game, faction: faction)] ?? []
    }

    static func unit(id: String) -> CatalogUnit? {
        loadIfNeeded()
        return byId[id]
    }

    static func search(game: String, faction: String, query: String) -> [CatalogUnit] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let all = units(game: game, faction: faction)
        guard !q.isEmpty else { return all }
        return all.filter { u in
            u.name.lowercased().contains(q)
            || u.category.lowercased().contains(q)
            || u.keywords.contains { $0.lowercased().contains(q) }
            || u.aliases.contains { $0.lowercased().contains(q) }
        }
    }

    private static func factionKey(game: String, faction: String) -> String {
        "\(game):\(FactionResolver.normalize(faction))"
    }

    private static func decode<T: Decodable>(_ name: String, _ type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json",
                                        subdirectory: "UnitCatalog") else { return nil }
        return try? JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    private static func decodePath<T: Decodable>(_ path: String, _ type: T.Type) -> T? {
        let parts = path.split(separator: "/")
        guard parts.count == 2 else { return nil }
        guard let url = Bundle.main.url(forResource: String(parts[1].dropLast(5)),
                                        withExtension: "json",
                                        subdirectory: "UnitCatalog/\(parts[0])") else { return nil }
        return try? JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
```

**Bundle note:** JSON files live under `MiniMuster/Resources/UnitCatalog/`. subdirectory in `Bundle.main.url` is `"UnitCatalog"` if files are copied flat into bundle, or adjust after verifying `Bundle.main` path in a unit test.

---

## Sample catalog JSON

### `manifest.json`

```json
{
  "version": "2026.06.1",
  "generatedAt": "2026-06-15",
  "attribution": "Unofficial community points; not affiliated with Games Workshop.",
  "games": ["40k"]
}
```

### `index.json`

```json
{
  "factions": {
    "40k:Grey Knights": "40k/grey-knights.json",
    "40k:Space Marines": "40k/space-marines.json",
    "40k:Necrons": "40k/necrons.json",
    "40k:Orks": "40k/orks.json",
    "40k:Chaos Space Marines": "40k/chaos-space-marines.json"
  }
}
```

### `40k/grey-knights.json` (implement fully; others may stub `"units": []` initially)

```json
{
  "faction": "Grey Knights",
  "game": "40k",
  "units": [
    {
      "id": "40k:grey-knights:castellan-crowe",
      "name": "Castellan Crowe",
      "faction": "Grey Knights",
      "game": "40k",
      "category": "Character",
      "basePoints": 90,
      "modelCount": 1,
      "keywords": ["Character", "Epic Hero", "Infantry"],
      "aliases": ["Crowe"],
      "boxSources": ["Grey Knights Combat Patrol"],
      "edition": "10th",
      "pointsKey": "2025-06"
    },
    {
      "id": "40k:grey-knights:brother-captain",
      "name": "Brother-Captain",
      "faction": "Grey Knights",
      "game": "40k",
      "category": "Character",
      "basePoints": 95,
      "modelCount": 1,
      "keywords": ["Character", "Infantry"],
      "aliases": [],
      "boxSources": [],
      "edition": "10th",
      "pointsKey": "2025-06"
    },
    {
      "id": "40k:grey-knights:interceptor-squad",
      "name": "Interceptor Squad",
      "faction": "Grey Knights",
      "game": "40k",
      "category": "Battleline",
      "basePoints": 95,
      "modelCount": 5,
      "keywords": ["Battleline", "Infantry", "Fly"],
      "aliases": ["Interceptors"],
      "boxSources": [],
      "edition": "10th",
      "pointsKey": "2025-06"
    },
    {
      "id": "40k:grey-knights:strike-squad",
      "name": "Strike Squad",
      "faction": "Grey Knights",
      "game": "40k",
      "category": "Battleline",
      "basePoints": 95,
      "modelCount": 5,
      "keywords": ["Battleline", "Infantry"],
      "aliases": ["Grey Knights Strike Squad"],
      "boxSources": ["Grey Knights Combat Patrol"],
      "edition": "10th",
      "pointsKey": "2025-06"
    },
    {
      "id": "40k:grey-knights:terminator-squad",
      "name": "Terminator Squad",
      "faction": "Grey Knights",
      "game": "40k",
      "category": "Elite",
      "basePoints": 190,
      "modelCount": 5,
      "keywords": ["Infantry", "Terminator"],
      "aliases": ["Brotherhood Terminators", "Paladin Squad"],
      "boxSources": ["Grey Knights Combat Patrol"],
      "edition": "10th",
      "pointsKey": "2025-06"
    },
    {
      "id": "40k:grey-knights:nemesis-dreadknight",
      "name": "Nemesis Dreadknight",
      "faction": "Grey Knights",
      "game": "40k",
      "category": "Vehicle",
      "basePoints": 210,
      "modelCount": 1,
      "keywords": ["Vehicle", "Walker"],
      "aliases": ["Dreadknight"],
      "boxSources": ["Grey Knights Combat Patrol"],
      "edition": "10th",
      "pointsKey": "2025-06"
    },
    {
      "id": "40k:grey-knights:venerable-dreadnought",
      "name": "Venerable Dreadnought",
      "faction": "Grey Knights",
      "game": "40k",
      "category": "Vehicle",
      "basePoints": 140,
      "modelCount": 1,
      "keywords": ["Vehicle", "Dreadnought"],
      "aliases": [],
      "boxSources": ["Grey Knights Combat Patrol"],
      "edition": "10th",
      "pointsKey": "2025-06"
    }
  ]
}
```

Fix typo `grey-knills` → `grey-knights` before shipping if present in drafts.

**Agent task:** Populate Space Marines / Necrons / Orks / CSM with at least 20 units each before calling Phase 1 done (GK file is the template).

---

## Domain — points & export

### `BattleSize.swift`

```swift
struct BattleSize: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let pointsLimit: Int
    let game: String
}

enum BattleSizes {
    static func forGame(_ game: String) -> [BattleSize] {
        switch game {
        case "40k": return warhammer40k
        default: return []
        }
    }

    static func resolve(game: String, key: String) -> BattleSize? {
        forGame(game).first { $0.id == key }
    }

    private static let warhammer40k: [BattleSize] = [
        .init(id: "incursion", label: "Incursion", pointsLimit: 1000, game: "40k"),
        .init(id: "strike-force", label: "Strike Force", pointsLimit: 2000, game: "40k"),
        .init(id: "onslaught", label: "Onslaught", pointsLimit: 3000, game: "40k"),
    ]
}
```

### `RosterPoints.swift`

```swift
enum RosterPoints {
    static func total(_ entries: [RosterEntry]) -> Int {
        entries.reduce(0) { $0 + $1.pointsTotal }
    }

    static func limit(for roster: Roster) -> Int {
        BattleSizes.resolve(game: roster.game, key: roster.battleSizeKey)?.pointsLimit ?? 0
    }

    static func remaining(for roster: Roster) -> Int {
        limit(for: roster) - total(roster.orderedEntries)
    }

    static func isOverLimit(_ roster: Roster) -> Bool {
        let lim = limit(for: roster)
        return lim > 0 && total(roster.orderedEntries) > lim
    }

    static func fillFraction(_ roster: Roster) -> Double {
        let lim = limit(for: roster)
        guard lim > 0 else { return 0 }
        return min(1, Double(total(roster.orderedEntries)) / Double(lim))
    }
}
```

### `RosterExport.swift`

```swift
enum RosterExport {
    static func plainText(roster: Roster, overrides: [FactionPresetOverride]) -> String {
        let lim = RosterPoints.limit(for: roster)
        let total = RosterPoints.total(roster.orderedEntries)
        let size = BattleSizes.resolve(game: roster.game, key: roster.battleSizeKey)?.label ?? roster.battleSizeKey
        var lines: [String] = [
            "\(roster.name) — \(size) (\(lim) pts)",
            "Total: \(total) pts",
            ""
        ]
        for e in roster.orderedEntries {
            lines.append("• \(e.displayName) ×\(e.qty) — \(e.pointsTotal) pts")
        }
        lines.append("")
        lines.append("Built with MiniMuster (unofficial list)")
        return lines.joined(separator: "\n")
    }
}
```

Share via `ShareLink` or `UIActivityViewController` from roster editor toolbar.

---

## `RosterStore.swift`

Mirror `ArmyStore` style — `@MainActor enum`, `try? ctx.save()`.

```swift
enum RosterError: Error, Equatable {
    case nameTaken
    case nameEmpty
    case rosterLimit
    case entryLimit
    case catalogUnitNotFound
}

@MainActor
enum RosterStore {
    @discardableResult
    static func addRoster(name: String, game: String, faction: String,
                          battleSizeKey: String, linkedArmyId: UUID?,
                          in ctx: ModelContext) throws -> Roster {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw RosterError.nameEmpty }
        let all = (try? ctx.fetch(FetchDescriptor<Roster>())) ?? []
        guard all.count < Limits.maxRosters else { throw RosterError.rosterLimit }
        guard !all.contains(where: { $0.name == trimmed }) else { throw RosterError.nameTaken }

        let roster = Roster(name: trimmed, game: game, faction: faction, battleSizeKey: battleSizeKey)
        roster.linkedArmyId = linkedArmyId
        roster.sortIndex = (all.map(\.sortIndex).max() ?? -1) + 1
        roster.catalogVersion = UnitCatalogLoader.version
        ctx.insert(roster)
        try ctx.save()
        return roster
    }

    static func delete(_ roster: Roster, in ctx: ModelContext) {
        ctx.delete(roster)
        try? ctx.save()
    }

    @discardableResult
    static func duplicate(_ roster: Roster, in ctx: ModelContext) throws -> Roster {
        let copyName = uniqueName(base: "\(roster.name) copy", in: ctx)
        let copy = try addRoster(name: copyName, game: roster.game, faction: roster.faction,
                                 battleSizeKey: roster.battleSizeKey, linkedArmyId: roster.linkedArmyId,
                                 in: ctx)
        for e in roster.orderedEntries {
            _ = try addEntry(from: e.catalogUnitId, qty: e.qty, to: copy, in: ctx)
        }
        return copy
    }

    @discardableResult
    static func addEntry(from catalogUnitId: String, qty: Int = 1,
                         to roster: Roster, in ctx: ModelContext) throws -> RosterEntry {
        guard roster.entries.count < Limits.maxEntriesPerRoster else { throw RosterError.entryLimit }
        guard let unit = UnitCatalogLoader.unit(id: catalogUnitId) else { throw RosterError.catalogUnitNotFound }

        if let existing = roster.entries.first(where: { $0.catalogUnitId == catalogUnitId }) {
            setQty(existing, existing.qty + qty, in: ctx)
            return existing
        }

        let entry = RosterEntry(
            catalogUnitId: unit.id,
            displayName: unit.name,
            qty: qty,
            pointsEach: unit.basePoints,
            sortIndex: (roster.entries.map(\.sortIndex).max() ?? -1) + 1
        )
        entry.roster = roster
        ctx.insert(entry)
        roster.touch()
        roster.catalogVersion = UnitCatalogLoader.version
        try ctx.save()
        return entry
    }

    static func setQty(_ entry: RosterEntry, _ qty: Int, in ctx: ModelContext) {
        entry.qty = max(1, min(qty, Limits.maxRosterQty))
        entry.roster?.touch()
        try? ctx.save()
    }

    static func deleteEntry(_ entry: RosterEntry, in ctx: ModelContext) {
        entry.roster?.touch()
        ctx.delete(entry)
        try? ctx.save()
    }

    /// (P2) Import missing catalog units into linked or new collection army.
    static func importMissingToCollection(roster: Roster,
                                          pipeline: [PipelineStage],
                                          in ctx: ModelContext) throws -> Int {
        let firstStage = pipeline.first?.key ?? "Unassembled"
        let army = try resolveLinkedArmy(for: roster, in: ctx)
        let matches = CollectionMatcher.matchAll(roster: roster, armies: fetchArmies(ctx), in: ctx)
        var added = 0
        for (entry, result) in matches where result.status == .missing || result.status == .partial {
            let need = result.requiredQty - result.ownedQty
            guard need > 0 else { continue }
            let catalog = UnitCatalogLoader.unit(id: entry.catalogUnitId)
            let name = catalog?.name ?? entry.displayName
            _ = ArmyStore.addUnit(to: army, name: name, qty: 1, source: roster.name, state: firstStage, in: ctx)
            added += 1
        }
        return added
    }

    private static func fetchArmies(_ ctx: ModelContext) -> [Army] {
        (try? ctx.fetch(FetchDescriptor<Army>())) ?? []
    }

    private static func resolveLinkedArmy(for roster: Roster, in ctx: ModelContext) throws -> Army {
        if let id = roster.linkedArmyId,
           let army = fetchArmies(ctx).first(where: { $0.id == id }) { return army }
        // Create collection army with roster name if none linked
        guard ArmyStore.addArmy(name: roster.name, game: roster.game, faction: roster.faction, in: ctx),
              let army = fetchArmies(ctx).first(where: { $0.name == roster.name }) else {
            throw RosterError.nameTaken
        }
        roster.linkedArmyId = army.id
        try ctx.save()
        return army
    }

    private static func uniqueName(base: String, in ctx: ModelContext) -> String {
        let all = (try? ctx.fetch(FetchDescriptor<Roster>())) ?? []
        let names = Set(all.map(\.name))
        if !names.contains(base) { return base }
        var n = 2
        while names.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }
}
```

---

## Domain — name matching (P2)

### `UnitNameMatch.swift`

Separate from `SourceMatch` (which handles paint box strings).

```swift
enum UnitNameMatch {
    /// Normalize for comparison: lowercase, collapse whitespace, strip first "(...)" group.
    static func normalize(_ name: String) -> String {
        var s = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let inner = ModelCount.firstParenGroup(name) {
            s = s.replacingOccurrences(of: "(\(inner))", with: "")
        }
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// True if collection unit name matches catalog entry name or any alias.
    static func matches(collectionUnitName: String, catalogName: String, aliases: [String]) -> Bool {
        let c = normalize(collectionUnitName)
        guard !c.isEmpty else { return false }
        let candidates = [catalogName] + aliases
        for raw in candidates {
            let n = normalize(raw)
            if c == n { return true }
            if c.contains(n) || n.contains(c) { return true }
        }
        return false
    }
}
```

### `CollectionMatcher.swift` (P2)

```swift
struct CollectionMatchResult: Sendable {
    enum Status: Sendable { case owned, partial, missing, unknown }
    let entryId: UUID
    let status: Status
    let ownedQty: Int      // model count
    let requiredQty: Int   // model count
    let matchedUnitIds: [UUID]
}

enum CollectionMatcher {
    static func matchAll(roster: Roster, armies: [Army], in ctx: ModelContext) -> [(RosterEntry, CollectionMatchResult)] {
        let units = scopedCollectionUnits(roster: roster, armies: armies)
        return roster.orderedEntries.map { entry in
            (entry, match(entry: entry, collectionUnits: units))
        }
    }

    static func fieldablePercent(roster: Roster, armies: [Army], in ctx: ModelContext) -> Int {
        let results = matchAll(roster: roster, armies: armies, in: ctx)
        guard !results.isEmpty else { return 0 }
        let owned = results.filter { $0.1.status == .owned }.count
        return Int((Double(owned) / Double(results.count) * 100).rounded())
    }

    static func match(entry: RosterEntry, collectionUnits: [Unit]) -> CollectionMatchResult {
        let catalog = UnitCatalogLoader.unit(id: entry.catalogUnitId)
        let required = requiredModels(entry: entry, catalog: catalog)
        let matched = collectionUnits.filter { unit in
            UnitNameMatch.matches(collectionUnitName: unit.name,
                                  catalogName: entry.displayName,
                                  aliases: catalog?.aliases ?? [])
        }
        let owned = matched.reduce(0) { $0 + ModelCount.of(name: $1.name, qty: $1.qty) }
        let status: CollectionMatchResult.Status = {
            if catalog == nil { return .unknown }
            if owned >= required { return .owned }
            if owned > 0 { return .partial }
            return .missing
        }()
        return CollectionMatchResult(
            entryId: entry.id,
            status: status,
            ownedQty: owned,
            requiredQty: required,
            matchedUnitIds: matched.map(\.id)
        )
    }

    private static func requiredModels(entry: RosterEntry, catalog: CatalogUnit?) -> Int {
        let perEntry = catalog?.modelCount ?? 1
        return entry.qty * max(1, perEntry)
    }

    private static func scopedCollectionUnits(roster: Roster, armies: [Army]) -> [Unit] {
        if let id = roster.linkedArmyId, let army = armies.first(where: { $0.id == id }) {
            return army.units
        }
        let f = FactionResolver.normalize(roster.faction)
        return armies.filter {
            $0.game == roster.game && FactionResolver.normalize($0.faction) == f
        }.flatMap(\.units)
    }
}
```

---

## Navigation

### `MusterRoute.swift`

```swift
enum MusterRoute: Hashable {
    case roster(UUID)
}
```

### `AppRouter.swift` — full target shape

```swift
@Observable
@MainActor
final class AppRouter {
    enum Tab: String { case armies, muster, paints }
    var tab: Tab = .armies

    // Collection (existing)
    var pendingSourceFilter: String?
    var pendingDeepLink: AppDeepLink.Destination?
    var collectionSearch: String = ""

    // Muster
    var musterSearch: String = ""
    var pendingRosterId: UUID?
    var selectedRosterId: UUID?       // iPad split selection

    func showArmies(filteredBySource source: String) { /* existing */ }
    func open(_ destination: AppDeepLink.Destination) { /* existing */ }

    func openMuster(rosterId: UUID) {
        pendingRosterId = rosterId
        selectedRosterId = rosterId
        tab = .muster
    }

    func openCollection(armyId: UUID, unitId: UUID? = nil) {
        tab = .armies
        // CollectionTab must observe pendingArmyId — add @State handoff via router:
        pendingCollectionArmyId = armyId
        pendingCollectionUnitId = unitId
    }

    var pendingCollectionArmyId: UUID?
    var pendingCollectionUnitId: UUID?
}
```

**CollectionTab integration (P2):** On appear, if `router.pendingCollectionArmyId` set, assign `selectedArmyId` and clear.

### `AppDeepLink.swift`

```swift
enum Destination: Equatable, Sendable {
    case collectionBacklog
    case musterHome
    case musterRoster(UUID)
}

static func destination(from url: URL) -> Destination? {
    // existing backlog...
    guard url.scheme?.lowercased() == scheme else { return nil }
    let host = url.host?.lowercased() ?? ""
    let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let parts = path.split(separator: "/").map(String.init)

    if host == "muster" || (host.isEmpty && parts.first == "muster") {
        if parts.count == 1 || (parts.count == 1 && host == "muster") {
            return .musterHome
        }
        if let id = UUID(uuidString: parts.last ?? "") {
            return .musterRoster(id)
        }
        return .musterHome
    }
    // ...
}

static func musterURL(rosterId: UUID) -> URL {
    URL(string: "\(scheme)://muster/\(rosterId.uuidString.lowercased())")!
}
```

### `RootView.swift` tab block

```swift
Tab(value: AppRouter.Tab.muster) {
    MusterTab()
} label: {
    Label("Muster", systemImage: "flag.fill")
        .accessibilityIdentifier("tabMuster")
}
.badge(rosterCount)  // @Query rosters.count

.onChange(of: router.pendingRosterId) { _, id in
    guard let id else { return }
    // MusterTab consumes via router.selectedRosterId
}
.onOpenURL { url in
    if let dest = AppDeepLink.destination(from: url) {
        switch dest {
        case .collectionBacklog:
            router.open(.collectionBacklog)
        case .musterHome:
            router.tab = .muster
        case .musterRoster(let id):
            router.openMuster(rosterId: id)
        }
    }
}
```

---

## UI components

### `MusterTab.swift`

Copy structure from `CollectionTab.swift`:

- `usesSplitLayout` → sidebar = `MusterHomeView`, detail = `RosterEditorView` or empty state  
- iPhone: `NavigationStack` + `navigationDestination(for: MusterRoute.self)`  
- `onAppear { UnitCatalogLoader.loadIfNeeded() }`  
- Consume `router.pendingRosterId` in `.onAppear` / `.onChange`

### `MusterHomeView.swift`

```swift
@Query(sort: \Roster.sortIndex) private var rosters: [Roster]
@Query private var configs: [AppConfiguration]
@Environment(AppRouter.self) private var router
@State private var showNew = false
@State private var search = ""

// Row: CrestBadge + name + "\(total) / \(limit) pts" + (P2) fieldable %
// Context menu: Duplicate, Rename (sheet), Delete (confirm)
// Toolbar + → NewRosterSheet
// Empty: ContentUnavailableView + "New muster" button
```

### `NewRosterSheet.swift`

Reuse `AddArmySheet` field layout:

| Field | Binding |
|-------|---------|
| Game | `$game` — `["40k"]` only MVP |
| Faction | `FactionResolver.canonicalByGame[game]` |
| Battle size | `BattleSizes.forGame(game)` |
| Name | default `"\(faction) \(size.label)"` |
| Link army | optional Picker of armies where game+faction match |

On confirm: `try RosterStore.addRoster(...)` → dismiss → `router.openMuster(rosterId:)`

### `RosterEditorView.swift`

```swift
let rosterId: UUID
@Query private var rosters: [Roster]
@Query private var configs: [AppConfiguration]
@State private var showCatalog = false
@State private var entrySheet: RosterEntry?

private var roster: Roster? { rosters.first { $0.id == rosterId } }

var body: some View {
    if let roster {
        List {
            headerSection(roster)           // CrestBadge, battle size, notes
            ForEach(roster.orderedEntries) { entry in
                RosterEntryRow(entry: entry, roster: roster)  // P2: OwnershipBadge
            }
            .onDelete { /* RosterStore.deleteEntry */ }
        }
        .safeAreaInset(edge: .bottom) {
            RosterPointsBar(roster: roster)
        }
        .toolbar {
            ToolbarItem { Button("Add unit", systemImage: "plus") { showCatalog = true } }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Share…") { shareText = RosterExport.plainText(...) }
                    Button("Duplicate") { ... }
                    Button("Link army", ...)  // P2
                    Button("Add missing to collection", ...)  // P2
                    Divider()
                    Button("Delete list", role: .destructive) { ... }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showCatalog) {
            UnitCatalogBrowser(roster: roster) { catalogUnit in
                try? RosterStore.addEntry(from: catalogUnit.id, to: roster, in: context)
            }
        }
    } else {
        ContentUnavailableView("List not found", systemImage: "flag")
    }
}
```

### `RosterPointsBar.swift`

```swift
struct RosterPointsBar: View {
    let roster: Roster
    private var total: Int { RosterPoints.total(roster.orderedEntries) }
    private var limit: Int { RosterPoints.limit(for: roster) }
    private var over: Bool { RosterPoints.isOverLimit(roster) }

    var body: some View {
        VStack(spacing: 6) {
            ProgressView(value: RosterPoints.fillFraction(roster))
                .tint(over ? .red : .accentColor)
            HStack {
                Text("\(total) pts")
                    .font(.headline.monospacedDigit())
                Spacer()
                Text(limit > 0 ? "of \(limit)" : "No limit")
                    .foregroundStyle(over ? .red : .secondary)
            }
            .font(.subheadline)
        }
        .padding()
        .background(.bar)
        .accessibilityIdentifier("rosterPointsBar")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Points \(total) of \(limit)\(over ? ", over limit" : "")")
    }
}
```

### `UnitCatalogBrowser.swift`

```swift
struct UnitCatalogBrowser: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let roster: Roster
    let onPick: (CatalogUnit) -> Void

    @State private var search = ""

    private var units: [CatalogUnit] {
        UnitCatalogLoader.search(game: roster.game, faction: roster.faction, query: search)
    }

    private var grouped: [(String, [CatalogUnit])] {
        Dictionary(grouping: units, by: \.category)
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.0) { category, items in
                    Section(category) {
                        ForEach(items) { unit in
                            Button {
                                onPick(unit)
                            } label: {
                                HStack {
                                    Text(unit.name)
                                    Spacer()
                                    Text("\(unit.basePoints) pts")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                            .accessibilityIdentifier("catalogUnit-\(unit.id)")
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Units, keywords…")
            .navigationTitle("Add unit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("musterAddUnit")
    }
}
```

### `RosterEntryRow.swift`

```swift
// HStack: VStack(name, category caption) | Spacer | Text("\(entry.pointsTotal) pts") | Stepper
// Stepper calls RosterStore.setQty
// (P2) OwnershipBadge trailing
```

### `OwnershipBadge.swift` (P2)

```swift
struct OwnershipBadge: View {
    let status: CollectionMatchResult.Status
    // owned: checkmark.circle.fill green
    // partial: minus.circle.fill orange
    // missing: plus.circle.fill red
    // unknown: questionmark.circle gray
}
```

---

## Accessibility identifiers

| ID | View |
|----|------|
| `tabMuster` | Tab bar Muster |
| `musterAddUnit` | Unit catalog sheet |
| `rosterPointsBar` | Sticky points footer |
| `catalogUnit-{id}` | Catalog row (UI tests) |
| `musterNewRoster` | New roster confirm button |
| `musterShare` | Share menu action |

---

## Unit tests

Use `TestDatabase()` from `MiniMusterTests/TestSupport.swift`. After schema change, `TestDatabase` auto-includes new models via `AppContainer.previewContainer()`.

### `UnitCatalogTests.swift`

```swift
@Test("loads grey knights catalog from bundle")
func loadGK() {
    UnitCatalogLoader.loadIfNeeded()
    let units = UnitCatalogLoader.units(game: "40k", faction: "Grey Knights")
    #expect(units.count >= 5)
    #expect(units.contains { $0.id.contains("interceptor") })
}

@Test("search finds aliases")
func searchAlias() {
    UnitCatalogLoader.loadIfNeeded()
    let hits = UnitCatalogLoader.search(game: "40k", faction: "Grey Knights", query: "Interceptors")
    #expect(hits.contains { $0.name == "Interceptor Squad" })
}
```

### `RosterPointsTests.swift`

```swift
@Test("total and over limit")
func overLimit() {
    let r = Roster(name: "T", game: "40k", faction: "GK", battleSizeKey: "incursion")
    let e = RosterEntry(catalogUnitId: "x", displayName: "A", qty: 1, pointsEach: 1001, sortIndex: 0)
    r.entries = [e]
    #expect(RosterPoints.isOverLimit(r))
}
```

### `RosterStoreTests.swift`

```swift
@Test("addRoster rejects duplicate names")
@Test("addEntry merges same catalogUnitId qty")
@Test("duplicate copies entries")
@Test("entry limit enforced")
```

### `UnitNameMatchTests.swift`

```swift
@Test("Interceptor Squad matches Interceptors alias")
@Test("Strike Squad (5) normalizes to strike squad")
```

### `CollectionMatcherTests.swift` (P2)

```swift
@Test("owned when collection has enough models")
func owned() {
    let db = TestDatabase()
    let army = Army(name: "GK", game: "40k", faction: "Grey Knights")
    db.context.insert(army)
    let u = Unit(name: "Interceptor Squad", qty: 1, state: "Done")
    u.army = army
    db.context.insert(u)
    let roster = Roster(name: "List", game: "40k", faction: "Grey Knights", battleSizeKey: "strike-force")
    roster.linkedArmyId = army.id
    let entry = RosterEntry(catalogUnitId: "40k:grey-knights:interceptor-squad",
                            displayName: "Interceptor Squad", qty: 1, pointsEach: 95, sortIndex: 0)
    entry.roster = roster
    db.context.insert(roster)
    db.context.insert(entry)
    let result = CollectionMatcher.match(entry: entry, collectionUnits: army.units)
    #expect(result.status == .owned)
}
```

---

## UI smoke test (optional)

`MusterSmokeUITests.swift`:

1. Launch with `UI-Testing` + seeded data argument (add `UI-Testing-MusterSeed` that creates one roster if needed).  
2. Tap `tabMuster`.  
3. Tap new roster → pick GK → create.  
4. Add unit → pick Interceptor Squad.  
5. Assert `rosterPointsBar` label contains `95`.

---

## Backup v5 (when ready)

### `Snapshot.swift`

```swift
struct RosterEntryDTO: Codable, Equatable {
    var catalogUnitId: String?
    var displayName: String?
    var qty: Int?
    var pointsEach: Int?
    var sortIndex: Int?
}

struct RosterDTO: Codable, Equatable {
    var id: String?
    var name: String?
    var game: String?
    var faction: String?
    var battleSizeKey: String?
    var notes: String?
    var linkedArmyId: String?
    var catalogVersion: String?
    var entries: [RosterEntryDTO]?
}

// Snapshot:
var rosters: [RosterDTO]?
static let backupVersion = 5
static let allowedKeys: Set<String> = [..., "rosters"]
```

Web app ignores unknown `rosters` key; iOS restore must handle v3 backups without `rosters`.

---

## `AppConfiguration` (P2)

```swift
var hasSeenMusterIntro: Bool = false
var defaultBattleSizeKey40k: String = "strike-force"
```

---

## Acceptance criteria (Phase 1 done when)

- [ ] Three tabs visible; Muster is middle tab with `flag.fill`  
- [ ] Create roster: game, faction, battle size, name  
- [ ] Add units from catalog; qty stepper updates points  
- [ ] Points bar shows total/limit; red when over Incursion 1000  
- [ ] Duplicate and delete roster  
- [ ] Share plain-text list  
- [ ] Works offline (airplane mode)  
- [ ] iPad split: roster list + editor  
- [ ] VoiceOver reads points bar  
- [ ] All unit tests green  
- [ ] Grey Knights catalog has ≥7 units; can build ~500 pt list  

## Acceptance criteria (Phase 2 done when)

- [ ] Fieldable % on roster rows when collection has matching units  
- [ ] Add missing creates collection units with `source` = roster name  
- [ ] Link army picker persists `linkedArmyId`  
- [ ] Tap owned badge opens unit detail in Collection tab  

---

## Pitfalls

| Issue | Fix |
|-------|-----|
| Bundle can't find JSON | Add test `loads grey knights`; print `Bundle.main.urls(forResourcesWithExtension:subdirectory:)` |
| `Roster` confused with `Army` | Never rename types; use “roster” in UI for lists, “army” for collection |
| Points stale after catalog update | Compare `roster.catalogVersion` to manifest; show banner in editor |
| Faction picker mismatch | Always `FactionResolver.normalize` when matching armies |
| iPad empty detail | Same pattern as Collection — `ContentUnavailableView("Select a list")` |
| Swift 6 concurrency | Keep stores `@MainActor`; catalog loader is synchronous on main |

---

## Changelog

| Date | Notes |
|------|-------|
| 2026-06-15 | Agent implementation guide — Phase 1–2 complete spec |
