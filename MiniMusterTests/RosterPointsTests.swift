import Foundation
import Testing
@testable import MiniMuster

@Suite("RosterPoints")
struct RosterPointsTests {
    @Test("total and over limit")
    func overLimit() {
        let r = Roster(name: "T", game: "40k", faction: "GK", battleSizeKey: "incursion")
        let e = RosterEntry(catalogUnitId: "x", displayName: "A", qty: 1, pointsEach: 1001, sortIndex: 0)
        r.entries = [e]
        #expect(RosterPoints.isOverLimit(r))
    }

    @Test("remaining points")
    func remaining() {
        let r = Roster(name: "T", game: "40k", faction: "GK", battleSizeKey: "incursion")
        let e = RosterEntry(catalogUnitId: "x", displayName: "A", qty: 1, pointsEach: 400, sortIndex: 0)
        r.entries = [e]
        #expect(RosterPoints.remaining(for: r) == 600)
    }
}
