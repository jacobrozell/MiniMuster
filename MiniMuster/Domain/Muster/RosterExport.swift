import Foundation

enum RosterExport {
    static func plainText(roster: Roster, overrides: [FactionPresetOverride]) -> String {
        let lim = RosterPoints.limit(for: roster)
        let total = RosterPoints.total(roster.orderedEntries)
        let size = BattleSizes.resolve(game: roster.game, key: roster.battleSizeKey)?.label ?? roster.battleSizeKey
        var lines: [String] = [
            "\(roster.name) — \(size) (\(lim) pts)",
            "Total: \(total) pts",
            ""
        ]
        for e in roster.orderedEntries {
            lines.append("• \(e.displayName) ×\(e.qty) — \(e.pointsTotal) pts")
        }
        lines.append("")
        lines.append("Built with MiniMuster (unofficial list)")
        return lines.joined(separator: "\n")
    }
}
