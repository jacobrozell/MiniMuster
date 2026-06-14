import Testing
import SwiftData
@testable import MusterRoll

@Suite("Members / squad tracking")
@MainActor
struct MembersTests {
    /// Build a unit with squad members inside an in-memory context.
    func makeSquad(name: String, qty: Int, state: String) -> (ModelContext, Unit) {
        let container = AppContainer.previewContainer()
        let ctx = container.mainContext
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
        return (ctx, unit)
    }

    @Test("members inherit the unit state until overridden")
    func inheritance() {
        let (_, unit) = makeSquad(name: "Intercessors (5)", qty: 1, state: "Primed")
        #expect(unit.members.count == 5)
        #expect(Members.effectiveStates(of: unit).allSatisfy { $0 == "Primed" })

        unit.member(at: 0)?.state = "Done"
        let states = Members.effectiveStates(of: unit)
        #expect(states.filter { $0 == "Done" }.count == 1)
        #expect(states.filter { $0 == "Primed" }.count == 4)
    }

    @Test("state summary counts effective states")
    func summary() {
        let (_, unit) = makeSquad(name: "Squad (3)", qty: 1, state: "Based")
        unit.member(at: 0)?.state = "Done"
        #expect(Members.stateSummary(of: unit) == "2× Based, 1× Done")
    }

    @Test("advance clears a member override when it matches the new default")
    func advanceClears() {
        let p = DefaultPipeline.stages
        let (_, unit) = makeSquad(name: "Squad (2)", qty: 1, state: "Primed")
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
        let (_, unit) = makeSquad(name: "Squad (3)", qty: 1, state: "Unassembled")
        unit.member(at: 0)?.state = "Done"
        #expect(Members.unitMatchesStateFilter(unit, "Done"))
        #expect(Members.unitPassesQuickView(unit, pipeline: p, quickView: "ready"))
        #expect(Members.unitPassesQuickView(unit, pipeline: p, quickView: "backlog"))
    }
}
