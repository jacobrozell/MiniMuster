import Foundation

enum RosterPoints {
    static func total(_ entries: [RosterEntry]) -> Int {
        entries.reduce(0) { $0 + $1.pointsTotal }
    }

    static func limit(for roster: Roster) -> Int {
        BattleSizes.resolve(game: roster.game, key: roster.battleSizeKey)?.pointsLimit ?? 0
    }

    static func remaining(for roster: Roster) -> Int {
        limit(for: roster) - total(roster.orderedEntries)
    }

    static func isOverLimit(_ roster: Roster) -> Bool {
        let lim = limit(for: roster)
        return lim > 0 && total(roster.orderedEntries) > lim
    }

    static func fillFraction(_ roster: Roster) -> Double {
        let lim = limit(for: roster)
        guard lim > 0 else { return 0 }
        return min(1, Double(total(roster.orderedEntries)) / Double(lim))
    }
}
