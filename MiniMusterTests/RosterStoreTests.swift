import Foundation
import SwiftData
import Testing
@testable import MiniMuster

@Suite("RosterStore")
@MainActor
struct RosterStoreTests {
    private let db = TestDatabase()

    init() {
        UnitCatalogLoader.loadIfNeeded()
    }

    @Test("addRoster rejects duplicate names")
    func duplicateName() throws {
        _ = try RosterStore.addRoster(name: "GK List", game: "40k", faction: "Grey Knights",
                                      battleSizeKey: "strike-force", linkedArmyId: nil, in: db.context)
        do {
            _ = try RosterStore.addRoster(name: "GK List", game: "40k", faction: "Grey Knights",
                                          battleSizeKey: "strike-force", linkedArmyId: nil, in: db.context)
            Issue.record("Expected nameTaken")
        } catch RosterError.nameTaken {}
    }

    @Test("addEntry merges same catalogUnitId qty")
    func mergeQty() throws {
        let roster = try RosterStore.addRoster(name: "GK", game: "40k", faction: "Grey Knights",
                                               battleSizeKey: "strike-force", linkedArmyId: nil, in: db.context)
        let id = "40k:grey-knights:interceptor-squad"
        _ = try RosterStore.addEntry(from: id, qty: 1, to: roster, in: db.context)
        _ = try RosterStore.addEntry(from: id, qty: 2, to: roster, in: db.context)
        #expect(roster.entries.count == 1)
        #expect(roster.entries.first?.qty == 3)
    }

    @Test("duplicate copies entries")
    func duplicate() throws {
        let roster = try RosterStore.addRoster(name: "GK", game: "40k", faction: "Grey Knights",
                                               battleSizeKey: "strike-force", linkedArmyId: nil, in: db.context)
        _ = try RosterStore.addEntry(from: "40k:grey-knights:interceptor-squad", to: roster, in: db.context)
        let copy = try RosterStore.duplicate(roster, in: db.context)
        #expect(copy.entries.count == 1)
        #expect(copy.name != roster.name)
    }

    @Test("entry limit enforced")
    func entryLimit() throws {
        let roster = try RosterStore.addRoster(name: "Big", game: "40k", faction: "Grey Knights",
                                               battleSizeKey: "strike-force", linkedArmyId: nil, in: db.context)
        for i in 0..<Limits.maxEntriesPerRoster {
            let entry = RosterEntry(catalogUnitId: "test:\(i)", displayName: "U\(i)",
                                    qty: 1, pointsEach: 1, sortIndex: i)
            entry.roster = roster
            db.context.insert(entry)
        }
        try db.context.save()
        do {
            _ = try RosterStore.addEntry(from: "40k:grey-knights:interceptor-squad", to: roster, in: db.context)
            Issue.record("Expected entryLimit")
        } catch RosterError.entryLimit {}
    }
}
