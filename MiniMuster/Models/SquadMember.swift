import Foundation
import SwiftData

/// A per-model override within a multi-model unit. Mirrors the web `{ state?, notes? }`
/// member, with an explicit `index` because SwiftData relationships are unordered.
/// `nil` state/notes mean "inherit from the unit" (`Members.effectiveState`).
@Model
final class SquadMember {
    var id: UUID = UUID()
    var index: Int = 0       // 0-based model position within the unit
    var state: String?       // nil = inherit the unit's state
    var notes: String?       // nil = inherit the unit's notes
    var unit: Unit?

    init(index: Int, state: String? = nil, notes: String? = nil) {
        self.index = index
        self.state = state
        self.notes = notes
    }
}
