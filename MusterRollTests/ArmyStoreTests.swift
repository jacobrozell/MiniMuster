import Testing
import SwiftData
@testable import MusterRoll

@Suite("ArmyStore")
@MainActor
struct ArmyStoreTests {
    func newContext() -> ModelContext { AppContainer.previewContainer().mainContext }

    @Test("rejects duplicate army names")
    func dupArmy() {
        let ctx = newContext()
        #expect(ArmyStore.addArmy(name: "Vermindoom", game: "AoS", faction: "Skaven", in: ctx))
        #expect(!ArmyStore.addArmy(name: "Vermindoom", game: "AoS", faction: "Skaven", in: ctx))
    }

    @Test("addUnit assigns order and spearhead default from siblings")
    func addUnit() throws {
        let ctx = newContext()
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
        let ctx = newContext()
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
        let ctx = newContext()
        let a = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(a)
        let b = Army(name: "B", game: "40k", faction: "Orks"); ctx.insert(b)
        let u = Unit(name: "Boyz", state: "Primed", order: 0); u.army = a; ctx.insert(u)
        #expect(ArmyStore.move(u, to: b, in: ctx))
        #expect(a.units.isEmpty)
        #expect(b.units.count == 1)
    }

    @Test("mergeDuplicates sums qty for identical rows")
    func merge() {
        let ctx = newContext()
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
        let ctx = newContext()
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
        let ctx = newContext()
        let army = Army(name: "A", game: "40k", faction: "Space Marines"); ctx.insert(army)
        let u = Unit(name: "Intercessors (5)", qty: 1, state: "Primed", order: 0)
        u.army = army; ctx.insert(u)
        for i in 0..<5 { let m = SquadMember(index: i); m.unit = u; ctx.insert(m) }
        #expect(u.members.count == 5)
        ArmyStore.setQty(u, 2, in: ctx)        // modelCount 5 → 10
        #expect(u.modelCount == 10)
        #expect(u.members.count == 10)
    }
}
