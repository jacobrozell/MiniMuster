import Foundation
import SwiftData
import Testing
@testable import MiniMuster

@Suite("CollectionMatcher")
@MainActor
struct CollectionMatcherTests {
    private let db = TestDatabase()

    init() {
        UnitCatalogLoader.loadIfNeeded()
    }

    @Test("owned when collection has enough models")
    func owned() throws {
        let army = Army(name: "GK", game: "40k", faction: "Grey Knights")
        db.context.insert(army)
        let u = Unit(name: "Interceptor Squad (5)", qty: 1, state: "Done")
        u.army = army
        db.context.insert(u)
        let roster = Roster(name: "List", game: "40k", faction: "Grey Knights", battleSizeKey: "strike-force")
        roster.linkedArmyId = army.id
        let entry = RosterEntry(catalogUnitId: "40k:grey-knights:interceptor-squad",
                                displayName: "Interceptor Squad", qty: 1, pointsEach: 95, sortIndex: 0)
        entry.roster = roster
        db.context.insert(roster)
        db.context.insert(entry)
        try db.context.save()
        let result = CollectionMatcher.match(entry: entry, collectionUnits: army.units)
        #expect(result.status == .owned)
    }

    @Test("missing when no collection units")
    func missing() {
        let roster = Roster(name: "List", game: "40k", faction: "Grey Knights", battleSizeKey: "strike-force")
        let entry = RosterEntry(catalogUnitId: "40k:grey-knights:interceptor-squad",
                                displayName: "Interceptor Squad", qty: 1, pointsEach: 95, sortIndex: 0)
        entry.roster = roster
        let result = CollectionMatcher.match(entry: entry, collectionUnits: [])
        #expect(result.status == .missing)
    }

    @Test("fieldable percent counts owned entries")
    func fieldablePercent() throws {
        let army = Army(name: "GK", game: "40k", faction: "Grey Knights")
        db.context.insert(army)
        let u = Unit(name: "Interceptor Squad (5)", qty: 1, state: "Done")
        u.army = army
        db.context.insert(u)
        let roster = Roster(name: "List", game: "40k", faction: "Grey Knights", battleSizeKey: "strike-force")
        roster.linkedArmyId = army.id
        let owned = RosterEntry(catalogUnitId: "40k:grey-knights:interceptor-squad",
                                displayName: "Interceptor Squad", qty: 1, pointsEach: 95, sortIndex: 0)
        owned.roster = roster
        let missing = RosterEntry(catalogUnitId: "40k:grey-knights:nemesis-dreadknight",
                                  displayName: "Nemesis Dreadknight", qty: 1, pointsEach: 210, sortIndex: 1)
        missing.roster = roster
        db.context.insert(roster)
        db.context.insert(owned)
        db.context.insert(missing)
        try db.context.save()
        let pct = CollectionMatcher.fieldablePercent(roster: roster, armies: [army], in: db.context)
        #expect(pct == 50)
    }
}
