import Foundation

/// Plain value drafts produced by parsing/import, before insertion into SwiftData.
/// Sendable so parsing can run off the main actor; applied to a context on the main actor.

struct MemberDraft: Sendable, Equatable {
    var state: String?     // nil = inherit
    var notes: String?
}

struct UnitDraft: Sendable, Equatable {
    var name: String
    var qty: Int = 1
    var source: String = ""
    var state: String
    var spearhead: Bool? = nil
    var notes: String = ""
    var members: [MemberDraft] = []
}

struct ArmyDraft: Sendable, Equatable {
    var name: String
    var game: String
    var faction: String
    var crestOverride: String? = nil
    var colorOverrideHex: String? = nil
    var customPipeline: [PipelineStage]? = nil   // backup restore only; CSV import leaves nil
    var units: [UnitDraft] = []
}

struct PaintDraft: Sendable, Equatable {
    var name: String
    var type: String = ""
    var swatchHex: String = "#777"
    var qty: Int = 1
    var brand: String = ""
    var source: String = ""
    var notes: String = ""
    var low: Bool = false
}

/// Result of a CSV import. Mirrors the web `ImportResult`.
struct ImportResult: Sendable {
    var ok: Bool
    var errors: [String]
    var warnings: [String]
    var stats: [String: Int]
    var armies: [ArmyDraft]?
    var paints: [PaintDraft]?

    static func failure(_ errors: [String], warnings: [String] = []) -> ImportResult {
        ImportResult(ok: false, errors: errors, warnings: warnings, stats: [:], armies: nil, paints: nil)
    }
}
