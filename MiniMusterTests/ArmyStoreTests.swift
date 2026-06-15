import Testing
import SwiftData
@testable import MiniMuster

@Suite("ArmyStore", .serialized)
@MainActor
struct ArmyStoreTests {
    func newDatabase() -> TestDatabase { TestDatabase() }

    @Test("rejects duplicate army names")
    func dupArmy() {
        let db = newDatabase()
        let ctx = db.context
        #expect(ArmyStore.addArmy(name: "Vermindoom", game: "AoS", faction: "Skaven", in: ctx))
        #expect(!ArmyStore.addArmy(name: "Vermindoom", game: "AoS", faction: "Skaven", in: ctx))
    }

    @Test("addUnit assigns order and spearhead default from siblings")
    func addUnit() throws {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "AoS", faction: "Skaven")
        ctx.insert(army)
        let spear = Unit(name: "Existing", state: "Based", spearhead: true, order: 0)
        spear.army = army; ctx.insert(spear)

        #expect(ArmyStore.addUnit(to: army, name: "Clanrats (5)", qty: 2, source: "Box",
                                  state: "Primed", in: ctx))
        let added = army.orderedUnits.last
        #expect(added?.order == 1)
        #expect(added?.spearhead == false)   // army uses spearhead → new unit gets false
    }

    @Test("duplicate inserts a copy right after with contiguous order")
    func duplicate() {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks")
        ctx.insert(army)
        for (i, n) in ["X", "Y", "Z"].enumerated() {
            let u = Unit(name: n, state: "Primed", order: i); u.army = army; ctx.insert(u)
        }
        let y = army.orderedUnits[1]
        ArmyStore.duplicate(y, in: ctx)
        let names = army.orderedUnits.map(\.name)
        #expect(names == ["X", "Y", "Y", "Z"])
        #expect(army.orderedUnits.map(\.order) == [0, 1, 2, 3])
    }

    @Test("move transfers a unit between armies")
    func move() {
        let db = newDatabase()
        let ctx = db.context
        let a = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(a)
        let b = Army(name: "B", game: "40k", faction: "Orks"); ctx.insert(b)
        let u = Unit(name: "Boyz", state: "Primed", order: 0); u.army = a; ctx.insert(u)
        #expect(ArmyStore.move(u, to: b, in: ctx))
        #expect(a.units.isEmpty)
        #expect(b.units.count == 1)
    }

    @Test("mergeDuplicates sums qty for identical rows")
    func merge() {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "AoS", faction: "Skaven"); ctx.insert(army)
        for i in 0..<3 {
            let u = Unit(name: "Clanrats (5)", qty: 1, source: "Box", state: "Based", order: i)
            u.army = army; ctx.insert(u)
        }
        let removed = ArmyStore.mergeDuplicates(in: army, ctx: ctx)
        #expect(removed == 2)
        #expect(army.units.count == 1)
        #expect(army.units.first?.qty == 3)
    }

    @Test("advanceAll moves every advanceable unit one step")
    func advanceAll() {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        let a = Unit(name: "A", state: "Primed", order: 0); a.army = army; ctx.insert(a)
        let b = Unit(name: "B", state: "Done", order: 1); b.army = army; ctx.insert(b)   // can't advance
        let count = ArmyStore.advanceAll(in: army, global: nil, in: ctx)
        #expect(count == 1)
        #expect(a.state == "Base Coated")
        #expect(b.state == "Done")
    }

    @Test("changing qty resizes existing squad members")
    func resize() {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Space Marines"); ctx.insert(army)
        let u = Unit(name: "Intercessors (5)", qty: 1, state: "Primed", order: 0)
        u.army = army; ctx.insert(u)
        for i in 0..<5 { let m = SquadMember(index: i); m.unit = u; ctx.insert(m) }
        #expect(u.members.count == 5)
        ArmyStore.setQty(u, 2, in: ctx)        // modelCount 5 → 10
        #expect(u.modelCount == 10)
        #expect(u.members.count == 10)
    }

    @Test("custom pipeline overrides global stages for advance")
    func customPipeline() {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        army.customPipeline = [PipelineStage(key: "A", hex: "#111111"),
                               PipelineStage(key: "B", hex: "#222222")]
        let u = Unit(name: "Boyz", state: "A", order: 0); u.army = army; ctx.insert(u)
        ArmyStore.advanceAll(in: army, global: DefaultPipeline.stages, in: ctx)
        #expect(u.state == "B")
    }

    @Test("rename rejects blank, unchanged, and duplicate names")
    func rename() {
        let db = newDatabase()
        let ctx = db.context
        let a = Army(name: "Alpha", game: "40k", faction: "Orks"); ctx.insert(a)
        let b = Army(name: "Beta", game: "40k", faction: "Orks"); ctx.insert(b)
        #expect(ArmyStore.rename(a, to: "Gamma", in: ctx))
        #expect(a.name == "Gamma")
        #expect(!ArmyStore.rename(a, to: "Gamma", in: ctx))
        #expect(!ArmyStore.rename(a, to: "Beta", in: ctx))
        #expect(!ArmyStore.rename(a, to: "  ", in: ctx))
    }

    @Test("delete unit renumbers orders; delete army removes it")
    func delete() throws {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        for (i, n) in ["U0", "U1", "U2"].enumerated() {
            let u = Unit(name: n, state: "Primed", order: i); u.army = army; ctx.insert(u)
        }
        try ctx.save()
        ArmyStore.delete(army.orderedUnits[1], in: ctx)
        let units = try ctx.fetch(FetchDescriptor<Unit>())
        #expect(units.count == 2)
        #expect(units.sorted { $0.order < $1.order }.map(\.name) == ["U0", "U2"])

        ArmyStore.delete(army, in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Army>()).isEmpty)
    }

    @Test("addUnit and addArmy reject blank names")
    func blankNames() {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        #expect(!ArmyStore.addArmy(name: "", game: "40k", faction: "Orks", in: ctx))
        #expect(!ArmyStore.addUnit(to: army, name: "   ", qty: 1, source: "", state: "Primed", in: ctx))
        #expect(army.units.count == 0)
    }

    @Test("move returns false when source equals destination")
    func moveSameArmy() {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        let u = Unit(name: "Boyz", state: "Primed", order: 0); u.army = army; ctx.insert(u)
        #expect(!ArmyStore.move(u, to: army, in: ctx))
    }

    @Test("setState records undo; no-op when unchanged")
    func setState() {
        let db = newDatabase()
        let ctx = db.context
        UndoService.shared.clear()
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        let u = Unit(name: "Boyz", state: "Primed", order: 0); u.army = army; ctx.insert(u)
        ArmyStore.setState(u, "Primed", in: ctx)
        #expect(!UndoService.shared.canUndo)
        ArmyStore.setState(u, "Base Coated", in: ctx)
        #expect(UndoService.shared.canUndo)
        _ = UndoService.shared.undo(in: ctx)
        #expect(u.state == "Primed")
    }

    @Test("batch advance returns count and skips done units")
    func batchAdvance() {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        let a = Unit(name: "A", state: "Primed", order: 0); a.army = army; ctx.insert(a)
        let b = Unit(name: "B", state: "Done", order: 1); b.army = army; ctx.insert(b)
        let p = DefaultPipeline.stages
        #expect(ArmyStore.advance([a, b], pipeline: p, in: ctx) == 1)
        #expect(a.state == "Base Coated")
        #expect(b.state == "Done")
    }

    @Test("duplicate copies squad member overrides")
    func duplicateMembers() {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Space Marines"); ctx.insert(army)
        let u = Unit(name: "Intercessors (5)", qty: 1, state: "Primed", order: 0)
        u.army = army; ctx.insert(u)
        SquadStore.enable(u, in: ctx)
        u.member(at: 0)?.state = "Done"
        ArmyStore.duplicate(u, in: ctx)
        let copy = army.orderedUnits.last!
        #expect(copy.members.count == 5)
        #expect(copy.member(at: 0)?.state == "Done")
    }

    @Test("mergeDuplicates keeps rows with different member keys separate")
    func mergeMemberKeys() {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "AoS", faction: "Skaven"); ctx.insert(army)
        for i in 0..<2 {
            let u = Unit(name: "Clanrats (5)", qty: 1, source: "Box", state: "Based", order: i)
            u.army = army; ctx.insert(u)
            SquadStore.enable(u, in: ctx)
            if i == 1 { u.member(at: 0)?.state = "Done" }
        }
        #expect(ArmyStore.mergeDuplicates(in: army, ctx: ctx) == 0)
        #expect(army.units.count == 2)
    }

    @Test("resetTheme clears crest and colour overrides")
    func resetTheme() {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        army.crestOverride = "ORK"
        army.colorOverrideHex = "#ff0000"
        ArmyStore.resetTheme(army, in: ctx)
        #expect(army.crestOverride == nil)
        #expect(army.colorOverrideHex == nil)
    }

    @Test("collapse toggles and setCollapseAll persist")
    func collapse() {
        let db = newDatabase()
        let ctx = db.context
        let a = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(a)
        let b = Army(name: "B", game: "40k", faction: "Orks"); ctx.insert(b)
        ArmyStore.toggleCollapse(a, in: ctx)
        #expect(a.isCollapsed)
        ArmyStore.setCollapseAll(true, in: ctx)
        #expect(b.isCollapsed)
    }

    @Test("setSpearhead persists tri-state")
    func spearhead() {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        let u = Unit(name: "Boyz", state: "Primed", order: 0); u.army = army; ctx.insert(u)
        #expect(u.spearhead == nil)
        ArmyStore.setSpearhead(u, true, in: ctx)
        #expect(u.spearhead == true)
        ArmyStore.setSpearhead(u, false, in: ctx)
        #expect(u.spearhead == false)
    }

    @Test("advanceUnits respects per-army custom pipelines")
    func advanceUnitsCustom() {
        let db = newDatabase()
        let ctx = db.context
        let customArmy = Army(name: "Custom", game: "40k", faction: "Orks"); ctx.insert(customArmy)
        customArmy.customPipeline = [PipelineStage(key: "A", hex: "#111111"),
                                     PipelineStage(key: "B", hex: "#222222")]
        let customUnit = Unit(name: "U1", state: "A", order: 0); customUnit.army = customArmy; ctx.insert(customUnit)

        let stdArmy = Army(name: "Std", game: "40k", faction: "Orks"); ctx.insert(stdArmy)
        let stdUnit = Unit(name: "U2", state: "Primed", order: 0); stdUnit.army = stdArmy; ctx.insert(stdUnit)

        #expect(ArmyStore.advanceUnits([customUnit, stdUnit], global: DefaultPipeline.stages, in: ctx) == 2)
        #expect(customUnit.state == "B")
        #expect(stdUnit.state == "Base Coated")
    }

    @Test("advance single unit is a no-op when already done")
    func advanceSingleDone() {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        let u = Unit(name: "Hero", qty: 1, state: "Done", order: 0); u.army = army; ctx.insert(u)
        ArmyStore.advance(u, pipeline: DefaultPipeline.stages, in: ctx)
        #expect(u.state == "Done")
    }

    @Test("move renumbers destination army orders")
    func moveRenumbers() {
        let db = newDatabase()
        let ctx = db.context
        let a = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(a)
        let b = Army(name: "B", game: "40k", faction: "Orks"); ctx.insert(b)
        let u0 = Unit(name: "U0", state: "Primed", order: 0); u0.army = b; ctx.insert(u0)
        let u1 = Unit(name: "U1", state: "Primed", order: 0); u1.army = a; ctx.insert(u1)
        #expect(ArmyStore.move(u1, to: b, in: ctx))
        #expect(b.orderedUnits.map(\.name) == ["U0", "U1"])
        #expect(b.orderedUnits.map(\.order) == [0, 1])
    }

    @Test("mergeDuplicates adopts notes from removed rows")
    func mergeNotes() {
        let db = newDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        for (i, notes) in ["", "#wip"].enumerated() {
            let u = Unit(name: "Boyz (10)", qty: 1, source: "Box", state: "Primed", notes: notes, order: i)
            u.army = army; ctx.insert(u)
        }
        #expect(ArmyStore.mergeDuplicates(in: army, ctx: ctx) == 1)
        #expect(army.units.count == 1)
        #expect(army.units.first?.qty == 2)
        #expect(army.units.first?.notes == "#wip")
    }
}
