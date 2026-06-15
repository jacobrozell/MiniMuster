import Foundation
import SwiftData

@Model
final class Roster {
    var id: UUID = UUID()
    var name: String = ""
    var game: String = "40k"
    var faction: String = ""
    var battleSizeKey: String = "strike-force"
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sortIndex: Int = 0
    var linkedArmyId: UUID?
    var catalogVersion: String = ""

    @Relationship(deleteRule: .cascade, inverse: \RosterEntry.roster)
    var entries: [RosterEntry] = []

    init(name: String, game: String, faction: String, battleSizeKey: String) {
        self.name = name.capped(Limits.maxStringLen)
        self.game = game
        self.faction = faction
        self.battleSizeKey = battleSizeKey
    }
}

extension Roster {
    var orderedEntries: [RosterEntry] {
        entries.sorted {
            if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func presentation(overrides: [FactionPresetOverride]) -> (crest: String, colorHex: String) {
        let r = FactionResolver.resolve(faction: faction, game: game, overrides: overrides)
        return (r.crest, r.color)
    }

    func touch() { updatedAt = Date() }
}
