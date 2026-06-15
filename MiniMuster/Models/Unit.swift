import Foundation
import SwiftData

/// One entry in an army. May represent many physical models. Mirrors the web unit row
/// `{ unit, qty, source, state, spearhead?, notes, members? }`.
@Model
final class Unit {
    var id: UUID = UUID()

    var name: String = ""        // web: `unit`
    var qty: Int = 1             // clamped 1...9999
    var source: String = ""
    var state: String = ""       // a pipeline stage key
    var notes: String = ""

    /// Tri-state spearhead (web semantics):
    ///   nil   = army/game does not use spearhead → no control shown
    ///   false = applicable but not picked
    ///   true  = spearhead pick
    var spearhead: Bool?

    var order: Int = 0           // position within the army

    var army: Army?

    @Relationship(deleteRule: .cascade, inverse: \SquadMember.unit)
    var members: [SquadMember] = []

    @Relationship(deleteRule: .cascade, inverse: \ModelPhoto.unit)
    var photos: [ModelPhoto] = []

    @Relationship(deleteRule: .cascade, inverse: \StageEvent.unit)
    var stageEvents: [StageEvent] = []

    init(name: String,
         qty: Int = 1,
         source: String = "",
         state: String,
         notes: String = "",
         spearhead: Bool? = nil,
         order: Int = 0) {
        self.name = name
        self.qty = max(1, qty)
        self.source = source
        self.state = state
        self.notes = notes
        self.spearhead = spearhead
        self.order = order
    }
}

extension Unit {
    /// Estimated physical model count: Qty × (sum of numbers in the first (...) group, or 1).
    var modelCount: Int { ModelCount.of(name: name, qty: qty) }

    /// True when per-model squad tracking is enabled.
    var hasSquadMembers: Bool { !members.isEmpty }

    /// Eligible squad size (== modelCount). Per-model tracking needs >= 2.
    var squadSize: Int { modelCount }

    /// The squad member at a given 0-based index, if tracking is on.
    func member(at index: Int) -> SquadMember? {
        members.first { $0.index == index }
    }

    var orderedMembers: [SquadMember] {
        members.sorted { $0.index < $1.index }
    }

    var coverPhoto: ModelPhoto? {
        photos.first(where: \.isCover) ?? orderedPhotos.first
    }

    var orderedPhotos: [ModelPhoto] {
        photos.sorted {
            if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
            return $0.createdAt < $1.createdAt
        }
    }

    var orderedStageEvents: [StageEvent] {
        stageEvents.sorted { $0.occurredAt < $1.occurredAt }
    }
}
