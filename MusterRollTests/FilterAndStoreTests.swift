import Testing
import SwiftData
@testable import MusterRoll

@MainActor
private func seededContext() -> ModelContext {
    let ctx = AppContainer.previewContainer().mainContext
    let a = Army(name: "Vermindoom", game: "AoS", faction: "Skaven", sortIndex: 0); ctx.insert(a)
    let u1 = Unit(name: "Clanrats (5)", qty: 1, source: "Skaventide", state: "Based",
                  notes: "#wip", order: 0); u1.army = a; ctx.insert(u1)
    let u2 = Unit(name: "Rat Ogors", qty: 3, source: "Skaventide", state: "Unassembled", order: 1)
    u2.army = a; ctx.insert(u2)
    let b = Army(name: "GK", game: "40k", faction: "Grey Knights", sortIndex: 1); ctx.insert(b)
    let u3 = Unit(name: "Strike Squad (5)", qty: 1, source: "Combat Patrol", state: "Done", order: 0)
    u3.army = b; ctx.insert(u3)
    try? ctx.save()
    return ctx
}

@Suite("ArmyFilter")
@MainActor
struct ArmyFilterTests {
    func armies(_ ctx: ModelContext) -> [Army] {
        ((try? ctx.fetch(FetchDescriptor<Army>())) ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    @Test("game filter narrows to one army")
    func gameFilter() {
        let ctx = seededContext()
        let cfg = Config.current(ctx)
        cfg.gameFilter = "40k"
        let vis = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "", global: nil)
        #expect(vis.count == 1)
        #expect(vis.first?.army.name == "GK")
    }

    @Test("quick view 'ready' keeps only table-ready units")
    func quickView() {
        let ctx = seededContext()
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
        let ctx = seededContext()
        let cfg = Config.current(ctx)
        let vis = ArmyFilter.build(armies: armies(ctx), cfg: cfg, search: "ogors", global: nil)
        #expect(vis.flatMap { $0.units }.map(\.name) == ["Rat Ogors"])
    }

    @Test("tag and source enumeration")
    func enumerate() {
        let ctx = seededContext()
        #expect(ArmyFilter.allNoteTags(armies(ctx)) == ["wip"])
        #expect(ArmyFilter.allSources(armies(ctx)).contains("Skaventide"))
    }
}

@Suite("SquadStore")
@MainActor
struct SquadStoreTests {
    func makeUnit() -> (ModelContext, Unit) {
        let ctx = AppContainer.previewContainer().mainContext
        let army = Army(name: "A", game: "40k", faction: "Space Marines"); ctx.insert(army)
        let u = Unit(name: "Intercessors (5)", qty: 1, state: "Primed", order: 0)
        u.army = army; ctx.insert(u)
        return (ctx, u)
    }

    @Test("enable creates inheriting members; disable removes them")
    func enableDisable() {
        let (ctx, u) = makeUnit()
        #expect(SquadStore.enable(u, in: ctx))
        #expect(u.members.count == 5)
        #expect(Members.effectiveStates(of: u).allSatisfy { $0 == "Primed" })
        SquadStore.disable(u, in: ctx)
        #expect(u.members.isEmpty)
    }

    @Test("setMemberState inherits when matching the default")
    func inherit() {
        let (ctx, u) = makeUnit()
        SquadStore.enable(u, in: ctx)
        SquadStore.setMemberState(u, index: 0, state: "Done", in: ctx)
        #expect(u.member(at: 0)?.state == "Done")
        SquadStore.setMemberState(u, index: 0, state: "Primed", in: ctx)  // == default
        #expect(u.member(at: 0)?.state == nil)
    }
}

@Suite("PaintStore")
@MainActor
struct PaintStoreTests {
    @Test("rejects duplicate names case-insensitively")
    func dup() {
        let ctx = AppContainer.previewContainer().mainContext
        #expect(PaintStore.add(name: "Khorne Red", type: "Base", brand: "", source: "",
                               qty: 1, notes: "", low: false, in: ctx))
        #expect(!PaintStore.add(name: "khorne red", type: "Base", brand: "", source: "",
                                qty: 1, notes: "", low: false, in: ctx))
    }

    @Test("counts linked units via fuzzy source match")
    func linked() {
        let ctx = seededContext()
        let armies = (try? ctx.fetch(FetchDescriptor<Army>())) ?? []
        #expect(PaintStore.linkedUnitCount(source: "Skaventide", armies: armies) == 2)
    }
}

@Suite("UndoService")
@MainActor
struct UndoServiceTests {
    @Test("undo restores a deleted unit and reverts a state change")
    func undo() {
        let ctx = seededContext()
        let undo = UndoService()
        // Use the shared recorder path via ArmyStore (records to UndoService.shared),
        // but assert restoration semantics directly on a fresh service for isolation.
        let army = (try? ctx.fetch(FetchDescriptor<Army>())) ?? []
        let unit = army.first!.orderedUnits.first!
        undo.record(.unitState(id: unit.id, previous: "Unassembled"))
        unit.state = "Done"
        _ = undo.undo(in: ctx)
        #expect(unit.state == "Unassembled")

        undo.record(.deleteUnit(UndoService.snapshot(unit)))
        let armyRef = unit.army!
        ctx.delete(unit)
        #expect(armyRef.units.count == 1)
        _ = undo.undo(in: ctx)
        #expect(armyRef.units.count == 2)
    }
}
