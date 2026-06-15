import Foundation

/// Codable DTOs matching the web JSON backup shape EXACTLY (`exportSnapshot` in
/// `js/core/store.js`) so backups round-trip between the web app and iOS. Field names mirror
/// the web keys (`army`, `unit`, `color`, `armySort: "csv"`, etc.).

struct MemberDTO: Codable, Equatable {
    var state: String?
    var notes: String?
}

struct UnitDTO: Codable, Equatable {
    var unit: String?
    var qty: Int?
    var source: String?
    var state: String?
    var spearhead: Bool?
    var notes: String?
    var members: [MemberDTO]?
}

struct ArmyDTO: Codable, Equatable {
    var army: String?
    var game: String?
    var faction: String?
    var crest: String?
    var color: String?
    var crestOverride: String?
    var colorOverride: String?
    var pipeline: [PipelineStage]?
    var units: [UnitDTO]?
}

struct PaintDTO: Codable, Equatable {
    var name: String?
    var type: String?
    var swatch: String?
    var qty: Int?
    var brand: String?
    var source: String?
    var notes: String?
    var low: Bool?
}

struct SettingsDTO: Codable, Equatable {
    var theme: String?
    var pipeline: [PipelineStage]?
    /// key → [crest, hex]; web `Record<string,[string,string]>`.
    var factionPresets: [String: [String]]?
    var collapsedArmies: [String]?
    var gameFilter: String?
    var factionFilter: String?
    var stateFilter: String?
    var sourceFilter: String?
    var spearheadOnly: Bool?
    var armySort: String?      // web uses "csv" for import order
    var unitSort: String?
    var quickView: String?
    var tagFilter: String?
    var lastBackupAt: String?
}

struct Snapshot: Codable {
    var version: Int?
    var collection: [ArmyDTO]?
    var paints: [PaintDTO]?
    var settings: SettingsDTO?
    var exportedAt: String?
}

extension Snapshot {
    /// Allowed top-level keys for the strict-keys check (mirrors `BACKUP_KEYS`).
    static let allowedKeys: Set<String> = ["version", "collection", "paints", "settings", "exportedAt"]
    static let backupVersion = 3
}
