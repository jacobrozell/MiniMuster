import Testing
import SwiftData
@testable import MusterRoll

fileprivate typealias Unit = MusterRoll.Unit

@MainActor
private func seededDatabase() -> TestDatabase {
    let db = TestDatabase()
    let ctx = db.context
    let a = Army(name: "Vermindoom", game: "AoS", faction: "Skaven", sortIndex: 0); ctx.insert(a)
    let u1 = Unit(name: "Clanrats (5)", qty: 1, source: "Skaventide", state: "Based",
                  notes: "#wip", order: 0); u1.army = a; ctx.insert(u1)
    let u2 = Unit(name: "Rat Ogors", qty: 3, source: "Skaventide", state: "Unassembled", order: 1)
    u2.army = a; ctx.insert(u2)
    let b = Army(name: "GK", game: "40k", faction: "Grey Knights", sortIndex: 1); ctx.insert(b)
    let u3 = Unit(name: "Strike Squad (5)", qty: 1, source: "Combat Patrol", state: "Done", order: 0)
    u3.army = b; ctx.insert(u3)
    try? ctx.save()
    return db
}

@Suite("ArmyFilter", .serialized)
@MainActor
struct ArmyFilterTests {
    func armies(_ ctx: ModelContext) -> [Army] {
        ((try? ctx.fetch(FetchDescriptor<Army>())) ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    @Test("game filter narrows to one army")
    func gameFilter() {
        let db = seededDatabase()
        let ctx = db.context
        let cfg = Config.current(ctx)
        cfg.gameFilter = "40k"
        let vis = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "", global: nil)
        #expect(vis.count == 1)
        #expect(vis.first?.army.name == "GK")
    }

    @Test("quick view 'ready' keeps only table-ready units")
    func quickView() {
        let db = seededDatabase()
        let ctx = db.context
        let cfg = Config.current(ctx)
        cfg.quickViewRaw = "ready"
        let vis = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "", global: nil)
        let names = vis.flatMap { $0.units.map(\.name) }
        #expect(names.contains("Clanrats (5)"))   // Based
        #expect(names.contains("Strike Squad (5)")) // Done
        #expect(!names.contains("Rat Ogors"))       // Unassembled
    }

    @Test("search matches across fields")
    func search() {
        let db = seededDatabase()
        let ctx = db.context
        let cfg = Config.current(ctx)
        let vis = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "ogors", global: nil)
        #expect(vis.flatMap { $0.units }.map(\.name) == ["Rat Ogors"])
    }

    @Test("tag and source enumeration")
    func enumerate() {
        let db = seededDatabase()
        let ctx = db.context
        #expect(ArmyFilter.allNoteTags(armies(ctx)) == ["wip"])
        #expect(ArmyFilter.allSources(armies(ctx)).contains("Skaventide"))
    }

    @Test("isActive reflects any non-default filter or search")
    func isActive() {
        let db = seededDatabase()
        let cfg = Config.current(db.context)
        #expect(!ArmyFilter.isActive(cfg, search: ""))
        #expect(ArmyFilter.isActive(cfg, search: "x"))
        cfg.stateFilter = "Based"
        #expect(ArmyFilter.isActive(cfg, search: ""))
        ArmyFilter.clearFilters(cfg)
        #expect(!ArmyFilter.isActive(cfg, search: ""))
    }

    @Test("active filter count excludes search text")
    func activeFilterCount() {
        let db = seededDatabase()
        let cfg = Config.current(db.context)
        #expect(ArmyFilter.activeFilterCount(cfg) == 0)
        cfg.gameFilter = "40k"
        cfg.tagFilter = "wip"
        #expect(ArmyFilter.activeFilterCount(cfg) == 2)
    }

    @Test("state, source, tag, and spearhead filters narrow units")
    func unitFilters() {
        let db = seededDatabase()
        let ctx = db.context
        let cfg = Config.current(ctx)

        cfg.stateFilter = "Based"
        var vis = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "", global: nil)
        #expect(vis.flatMap(\.units).map(\.name) == ["Clanrats (5)"])

        ArmyFilter.clearFilters(cfg)
        cfg.sourceFilter = "Combat Patrol"
        vis = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "", global: nil)
        #expect(vis.flatMap(\.units).map(\.name) == ["Strike Squad (5)"])

        ArmyFilter.clearFilters(cfg)
        cfg.tagFilter = "wip"
        vis = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "", global: nil)
        #expect(vis.flatMap(\.units).map(\.name) == ["Clanrats (5)"])

        ArmyFilter.clearFilters(cfg)
        let army = armies(ctx).first { $0.name == "Vermindoom" }!
        army.orderedUnits.first?.spearhead = true
        cfg.spearheadOnly = true
        vis = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "", global: nil)
        #expect(vis.flatMap(\.units).map(\.name) == ["Clanrats (5)"])
    }

    @Test("quick view 'wip' keeps mid-pipeline units")
    func quickViewWip() {
        let db = seededDatabase()
        let ctx = db.context
        let cfg = Config.current(ctx)
        cfg.quickViewRaw = "wip"
        let names = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "", global: nil)
            .flatMap { $0.units.map(\.name) }
        #expect(!names.contains("Rat Ogors"))      // Unassembled = backlog
        #expect(!names.contains("Clanrats (5)"))   // Based = ready, not wip
        #expect(!names.contains("Strike Squad (5)"))
        // Promote one unit to a mid-pipeline state
        armies(ctx).first?.orderedUnits[0].state = "Primed"
        let wipNames = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "", global: nil)
            .flatMap { $0.units.map(\.name) }
        #expect(wipNames.contains("Clanrats (5)"))
    }

    @Test("active filters hide armies with no matching units")
    func hideEmptyArmies() {
        let db = seededDatabase()
        let ctx = db.context
        let cfg = Config.current(ctx)
        cfg.stateFilter = "Unassembled"   // only Rat Ogors — GK army hidden
        let vis = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "", global: nil)
        #expect(vis.count == 1)
        #expect(vis.first?.army.name == "Vermindoom")
    }

    @Test("search matches member notes and tags")
    func searchMembers() {
        let db = seededDatabase()
        let ctx = db.context
        let army = armies(ctx).first!
        let unit = army.orderedUnits[0]
        SquadStore.enable(unit, in: ctx)
        SquadStore.setMemberNotes(unit, index: 0, notes: "#hero", in: ctx)
        let cfg = Config.current(ctx)
        let vis = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "hero", global: nil)
        #expect(vis.flatMap(\.units).map(\.name) == ["Clanrats (5)"])
    }

    @Test("sort units by pipeline state then name")
    func sortUnits() {
        let db = seededDatabase()
        let ctx = db.context
        let cfg = Config.current(ctx)
        cfg.unitSortRaw = "state"
        let names = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "", global: nil)
            .first { $0.army.name == "Vermindoom" }?
            .units.map(\.name) ?? []
        #expect(names == ["Rat Ogors", "Clanrats (5)"])   // Unassembled before Based
    }

    @Test("sort armies by name and import order")
    func sortArmies() {
        let db = seededDatabase()
        let ctx = db.context
        let cfg = Config.current(ctx)
        cfg.armySortRaw = "name"
        var names = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "", global: nil)
            .map { $0.army.name }
        #expect(names == ["GK", "Vermindoom"])

        cfg.armySortRaw = "import"
        names = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "", global: nil)
            .map { $0.army.name }
        #expect(names == ["Vermindoom", "GK"])
    }

    @Test("sort armies by collection progress")
    func sortByProgress() {
        let db = seededDatabase()
        let ctx = db.context
        let cfg = Config.current(ctx)
        cfg.armySortRaw = "progress"
        let names = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "", global: nil)
            .map { $0.army.name }
        // Progress sort is ascending — lower-progress armies appear first.
        #expect(names.last == "GK")
    }
}

@Suite("SquadStore", .serialized)
@MainActor
struct SquadStoreTests {
    func makeUnit() -> (TestDatabase, MusterRoll.Unit) {
        let db = TestDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Space Marines"); ctx.insert(army)
        let u = MusterRoll.Unit(name: "Intercessors (5)", qty: 1, state: "Primed", order: 0)
        u.army = army; ctx.insert(u)
        return (db, u)
    }

    @Test("enable creates inheriting members; disable removes them")
    func enableDisable() {
        let (db, u) = makeUnit()
        let ctx = db.context
        #expect(SquadStore.enable(u, in: ctx))
        #expect(u.members.count == 5)
        #expect(Members.effectiveStates(of: u).allSatisfy { $0 == "Primed" })
        SquadStore.disable(u, in: ctx)
        #expect(u.members.isEmpty)
    }

    @Test("setMemberState inherits when matching the default")
    func inherit() {
        let (db, u) = makeUnit()
        let ctx = db.context
        SquadStore.enable(u, in: ctx)
        SquadStore.setMemberState(u, index: 0, state: "Done", in: ctx)
        #expect(u.member(at: 0)?.state == "Done")
        SquadStore.setMemberState(u, index: 0, state: "Primed", in: ctx)  // == default
        #expect(u.member(at: 0)?.state == nil)
    }

    @Test("enable rejects single-model units and duplicate enable")
    func enableGuards() {
        let (db, u) = makeUnit()
        let ctx = db.context
        let solo = MusterRoll.Unit(name: "Captain", qty: 1, state: "Primed", order: 1)
        solo.army = u.army; ctx.insert(solo)
        #expect(!SquadStore.enable(solo, in: ctx))
        #expect(SquadStore.enable(u, in: ctx))
        #expect(!SquadStore.enable(u, in: ctx))
    }

    @Test("setMemberNotes clears empty strings to nil")
    func memberNotes() {
        let (db, u) = makeUnit()
        let ctx = db.context
        SquadStore.enable(u, in: ctx)
        SquadStore.setMemberNotes(u, index: 1, notes: "drybrush", in: ctx)
        #expect(u.member(at: 1)?.notes == "drybrush")
        SquadStore.setMemberNotes(u, index: 1, notes: "", in: ctx)
        #expect(u.member(at: 1)?.notes == nil)
    }

    @Test("advanceMember steps one model and clears inherit-on-match")
    func advanceMember() {
        let (db, u) = makeUnit()
        let ctx = db.context
        let p = DefaultPipeline.stages
        SquadStore.enable(u, in: ctx)
        SquadStore.setMemberState(u, index: 0, state: "Primed", in: ctx)   // hold at default
        SquadStore.advanceMember(u, index: 0, pipeline: p, in: ctx)
        #expect(Members.effectiveState(of: u, at: 0) == "Base Coated")
        #expect(u.member(at: 0)?.state == "Base Coated")

        u.state = "Detailed"
        SquadStore.setMemberState(u, index: 0, state: "Base Coated", in: ctx)
        SquadStore.advanceMember(u, index: 0, pipeline: p, in: ctx)
        #expect(u.member(at: 0)?.state == nil)   // Detailed matches unit default
    }
}

@Suite("PaintStore", .serialized)
@MainActor
struct PaintStoreTests {
    @Test("rejects duplicate names case-insensitively")
    func dup() {
        let db = TestDatabase()
        let ctx = db.context
        #expect(PaintStore.add(name: "Khorne Red", type: "Base", brand: "", source: "",
                               qty: 1, notes: "", low: false, in: ctx))
        #expect(!PaintStore.add(name: "khorne red", type: "Base", brand: "", source: "",
                                qty: 1, notes: "", low: false, in: ctx))
    }

    @Test("counts linked units via fuzzy source match")
    func linked() {
        let db = seededDatabase()
        let ctx = db.context
        let armies = (try? ctx.fetch(FetchDescriptor<Army>())) ?? []
        #expect(PaintStore.linkedUnitCount(source: "Skaventide", armies: armies) == 2)
        #expect(PaintStore.linkedUnitCount(source: "", armies: armies) == 0)
    }

    @Test("update rejects duplicate names and clamps qty")
    func update() throws {
        let db = TestDatabase()
        let ctx = db.context
        #expect(PaintStore.add(name: "Khorne Red", type: "Base", brand: "", source: "",
                               qty: 1, notes: "", low: false, in: ctx))
        #expect(PaintStore.add(name: "Abaddon Black", type: "Base", brand: "", source: "",
                               qty: 1, notes: "", low: false, in: ctx))
        let red = (try? ctx.fetch(FetchDescriptor<Paint>()))?.first { $0.name == "Khorne Red" }
        let paint = try #require(red)
        #expect(!PaintStore.update(paint, name: "abaddon black", type: "Base", brand: "", source: "",
                                   qty: 1, notes: "", low: false, in: ctx))
        #expect(PaintStore.update(paint, name: "Khorne Red", type: "Layer", brand: "Citadel", source: "",
                                  qty: 99999, notes: "fav", low: true, in: ctx))
        #expect(paint.qty == 9999)
        #expect(paint.low == true)
    }

    @Test("delete removes paint from context")
    func delete() throws {
        let db = TestDatabase()
        let ctx = db.context
        #expect(PaintStore.add(name: "Contrast", type: "Contrast", brand: "", source: "",
                               qty: 1, notes: "", low: false, in: ctx))
        let paint = try #require((try? ctx.fetch(FetchDescriptor<Paint>()))?.first)
        PaintStore.delete(paint, in: ctx)
        #expect((try? ctx.fetch(FetchDescriptor<Paint>()))?.isEmpty == true)
    }

    @Test("add rejects blank names")
    func blankName() {
        let db = TestDatabase()
        let ctx = db.context
        #expect(!PaintStore.add(name: "   ", type: "Base", brand: "", source: "",
                                qty: 1, notes: "", low: false, in: ctx))
    }
}

@Suite("UndoService", .serialized)
@MainActor
struct UndoServiceTests {
    @Test("undo restores a deleted unit and reverts a state change")
    func undo() {
        let db = seededDatabase()
        let ctx = db.context
        let undo = UndoService()
        // Use the shared recorder path via ArmyStore (records to UndoService.shared),
        // but assert restoration semantics directly on a fresh service for isolation.
        let armies = ((try? ctx.fetch(FetchDescriptor<Army>())) ?? []).sorted { $0.sortIndex < $1.sortIndex }
        let unit = armies.first!.orderedUnits.first!
        undo.record(.unitState(id: unit.id, previous: "Unassembled"))
        unit.state = "Done"
        _ = undo.undo(in: ctx)
        #expect(unit.state == "Unassembled")

        undo.record(.deleteUnit(UndoService.snapshot(unit)))
        let armyRef = unit.army!
        ctx.delete(unit)
        try? ctx.save()
        #expect(armyRef.orderedUnits.count == 1)
        _ = undo.undo(in: ctx)
        try? ctx.save()
        #expect(armyRef.orderedUnits.count == 2)
    }

    @Test("undo restores a deleted army with units and members")
    func undoArmy() throws {
        let db = seededDatabase()
        let ctx = db.context
        let undo = UndoService()
        let army = armies(ctx).first { $0.name == "Vermindoom" }!
        let unit = army.orderedUnits[0]
        SquadStore.enable(unit, in: ctx)
        unit.member(at: 0)?.state = "Done"
        let snap = UndoService.snapshot(army)
        undo.record(.deleteArmy(snap))
        ctx.delete(army)
        try? ctx.save()
        #expect((try? ctx.fetch(FetchDescriptor<Army>()))?.count == 1)

        _ = undo.undo(in: ctx)
        let restored = (try? ctx.fetch(FetchDescriptor<Army>()))?.first(where: { $0.name == "Vermindoom" })
        let r = try #require(restored)
        #expect(r.orderedUnits.count == 2)
        #expect(r.orderedUnits[0].member(at: 0)?.state == "Done")
    }

    @Test("undo batch state reverts bulk advance")
    func undoBatch() throws {
        let db = newArmyDatabase()
        let ctx = db.context
        let undo = UndoService()
        let army = try #require((try? ctx.fetch(FetchDescriptor<Army>()))?.first)
        let units = army.orderedUnits
        undo.record(.batchStates(units.map { ($0.id, $0.state) }))
        for u in units { Pipeline.advanceOneStep(u, DefaultPipeline.stages) }
        _ = undo.undo(in: ctx)
        #expect(units.map(\.state) == ["Primed", "Assembled"])
    }

    @Test("stack is capped at max depth")
    func stackCap() {
        let undo = UndoService()
        let db = seededDatabase()
        let id = armies(db.context).first!.orderedUnits.first!.id
        for i in 0..<35 {
            undo.record(.unitState(id: id, previous: "S\(i)"))
        }
        #expect(undo.stack.count == 30)
    }

    @Test("clear empties the undo stack")
    func clear() {
        let undo = UndoService()
        let db = seededDatabase()
        let id = armies(db.context).first!.orderedUnits.first!.id
        undo.record(.unitState(id: id, previous: "Primed"))
        undo.clear()
        #expect(!undo.canUndo)
    }

    private func armies(_ ctx: ModelContext) -> [Army] {
        ((try? ctx.fetch(FetchDescriptor<Army>())) ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    private func newArmyDatabase() -> TestDatabase {
        let db = TestDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        for (i, state) in ["Primed", "Assembled"].enumerated() {
            let u = MusterRoll.Unit(name: "U\(i)", state: state, order: i); u.army = army; ctx.insert(u)
        }
        try? ctx.save()
        return db
    }
}
