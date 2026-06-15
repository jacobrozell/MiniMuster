import Foundation

struct CatalogUnit: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let faction: String
    let game: String
    let category: String
    let basePoints: Int
    let modelCount: Int
    let keywords: [String]
    let aliases: [String]
    let boxSources: [String]
    let edition: String
    let pointsKey: String
}

struct FactionCatalogFile: Codable {
    let faction: String
    let game: String
    let units: [CatalogUnit]
}

struct UnitCatalogManifest: Codable {
    let version: String
    let generatedAt: String
    let attribution: String
    let games: [String]
}

struct UnitCatalogIndex: Codable {
    /// "40k:Grey Knights" → "40k/grey-knights.json"
    let factions: [String: String]
}
