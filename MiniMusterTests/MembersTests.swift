import Testing
import SwiftData
@testable import MiniMuster

@Suite("Members / squad tracking", .serialized)
@MainActor
struct MembersTests {
    /// Build a unit with squad members inside an in-memory context.
    func makeSquad(name: String, qty: Int, state: String) -> (TestDatabase, Unit) {
        let db = TestDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Space Marines")
        ctx.insert(army)
        let unit = Unit(name: name, qty: qty, state: state)
        unit.army = army
        ctx.insert(unit)
        for i in 0..<unit.modelCount {
            let m = SquadMember(index: i)
            m.unit = unit
            ctx.insert(m)
        }
        return (db, unit)
    }

    @Test("members inherit the unit state until overridden")
    func inheritance() {
        let (db, unit) = makeSquad(name: "Intercessors (5)", qty: 1, state: "Primed")
        _ = db
        #expect(unit.members.count == 5)
        #expect(Members.effectiveStates(of: unit).allSatisfy { $0 == "Primed" })

        unit.member(at: 0)?.state = "Done"
        let states = Members.effectiveStates(of: unit)
        #expect(states.filter { $0 == "Done" }.count == 1)
        #expect(states.filter { $0 == "Primed" }.count == 4)
    }

    @Test("state summary counts effective states")
    func summary() {
        let (db, unit) = makeSquad(name: "Squad (3)", qty: 1, state: "Based")
        _ = db
        unit.member(at: 0)?.state = "Done"
        #expect(Members.stateSummary(of: unit) == "2× Based, 1× Done")
    }

    @Test("advance clears a member override when it matches the new default")
    func advanceClears() {
        let p = DefaultPipeline.stages
        let (db, unit) = makeSquad(name: "Squad (2)", qty: 1, state: "Primed")
        _ = db
        // Hold member 0 one step behind so advancing brings it level with the default.
        unit.member(at: 0)?.state = "Primed"
        unit.member(at: 1)?.state = "Base Coated"
        Pipeline.advanceOneStep(unit, p)
        // default Primed → Base Coated; member 0 Primed → Base Coated == default → cleared.
        #expect(unit.state == "Base Coated")
        #expect(unit.member(at: 0)?.state == nil)
    }

    @Test("state filter and quick views are squad-aware")
    func filters() {
        let p = DefaultPipeline.stages
        let (db, unit) = makeSquad(name: "Squad (3)", qty: 1, state: "Unassembled")
        _ = db
        unit.member(at: 0)?.state = "Done"
        #expect(Members.unitMatchesStateFilter(unit, "Done"))
        #expect(Members.unitPassesQuickView(unit, pipeline: p, quickView: "ready"))
        #expect(Members.unitPassesQuickView(unit, pipeline: p, quickView: "backlog"))
    }

    @Test("effectiveNotes inherit unit notes until overridden")
    func effectiveNotes() {
        let (db, unit) = makeSquad(name: "Squad (2)", qty: 1, state: "Primed")
        _ = db
        unit.notes = "squad note"
        #expect(Members.effectiveNotes(of: unit, at: 1) == "squad note")
        unit.member(at: 1)?.notes = "model note"
        #expect(Members.effectiveNotes(of: unit, at: 1) == "model note")
    }

    @Test("wip quick view requires mid-pipeline states")
    func wipQuickView() {
        let p = DefaultPipeline.stages
        let (db, unit) = makeSquad(name: "Squad (2)", qty: 1, state: "Unassembled")
        _ = db
        #expect(!Members.unitPassesQuickView(unit, pipeline: p, quickView: "wip"))
        unit.member(at: 0)?.state = "Primed"
        #expect(Members.unitPassesQuickView(unit, pipeline: p, quickView: "wip"))
    }

    @Test("state summary is empty without squad members")
    func summaryEmpty() {
        let db = TestDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        let unit = Unit(name: "Hero", qty: 1, state: "Primed", order: 0)
        unit.army = army; ctx.insert(unit)
        #expect(Members.stateSummary(of: unit) == "")
    }
}
