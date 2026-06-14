import Foundation
import SwiftData

/// A named list grouping unit entries. Mirrors the web `Army` typedef
/// (`js/core/constants.js`). We store only crest/colour *overrides* and resolve the
/// displayed crest/colour live from the faction catalogue (`FactionResolver`), matching the
/// direction of the web `getArmyPresentation`.
///
/// CloudKit-readiness (`docs/ios-spec/01-data-model.md §9`): every property has a default or
/// is optional, relationships are optional with inverses, and no `@Attribute(.unique)` is
/// used — uniqueness of `name` is enforced in app logic instead.
@Model
final class Army {
    var id: UUID = UUID()

    var name: String = ""            // web: `army` (display label + import grouping key)
    var game: String = ""            // e.g. "40k", "AoS"
    var faction: String = ""         // e.g. "Grey Knights"

    var crestOverride: String?       // <= 8 chars; nil = use faction preset
    var colorOverrideHex: String?    // validated hex; nil = use faction preset

    /// nil = use the global pipeline. Non-empty = army-specific stages.
    var customPipeline: [PipelineStage]?

    var sortIndex: Int = 0           // import / first-seen order
    var isCollapsed: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Unit.army)
    var units: [Unit] = []

    init(name: String, game: String, faction: String, sortIndex: Int = 0) {
        self.name = name
        self.game = game
        self.faction = faction
        self.sortIndex = sortIndex
    }
}

extension Army {
    /// Units in their persisted order (relationships are unordered in SwiftData).
    var orderedUnits: [Unit] {
        units.sorted { $0.order < $1.order }
    }
}
