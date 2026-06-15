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
    var wargearSelectionJSON: String? = nil

    var roster: Roster?

    var pointsTotal: Int { qty * pointsEach }

    init(catalogUnitId: String, displayName: String, qty: Int, pointsEach: Int, sortIndex: Int) {
        self.catalogUnitId = catalogUnitId
        self.displayName = displayName.capped(Limits.maxStringLen)
        self.qty = max(1, min(qty, Limits.maxRosterQty))
        self.pointsEach = max(0, pointsEach)
        self.sortIndex = sortIndex
    }
}
