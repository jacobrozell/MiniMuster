import Foundation

/// One stage in a painting pipeline. Mirrors the web `{ key, hex }` PipelineStage typedef
/// (`js/core/constants.js`). Stored inline (Codable) on `Army.customPipeline` and
/// `AppConfiguration.globalPipeline`.
struct PipelineStage: Codable, Hashable, Identifiable, Sendable {
    var key: String   // display name, e.g. "Primed"
    var hex: String   // validated colour, e.g. "#f97316"
    var id: String { key }

    init(key: String, hex: String) {
        self.key = key
        self.hex = hex
    }
}

/// A user override for a faction's crest/colour, keyed by the composite "Game:Faction".
/// Mirrors the web `settings.factionPresets` map (`js/data/factions/build.js`).
struct FactionPresetOverride: Codable, Hashable, Identifiable, Sendable {
    var key: String     // "40k:Grey Knights"
    var crest: String   // <= 8 chars
    var hex: String     // validated colour
    var id: String { key }

    init(key: String, crest: String, hex: String) {
        self.key = key
        self.crest = crest
        self.hex = hex
    }
}
