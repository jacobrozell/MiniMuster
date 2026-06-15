import Foundation

struct BattleSize: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let pointsLimit: Int
    let game: String
}

enum BattleSizes {
    static func forGame(_ game: String) -> [BattleSize] {
        switch game {
        case "40k": return warhammer40k
        default: return []
        }
    }

    static func resolve(game: String, key: String) -> BattleSize? {
        forGame(game).first { $0.id == key }
    }

    private static let warhammer40k: [BattleSize] = [
        .init(id: "incursion", label: "Incursion", pointsLimit: 1000, game: "40k"),
        .init(id: "strike-force", label: "Strike Force", pointsLimit: 2000, game: "40k"),
        .init(id: "onslaught", label: "Onslaught", pointsLimit: 3000, game: "40k"),
    ]
}
