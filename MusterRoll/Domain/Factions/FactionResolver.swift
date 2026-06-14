import Foundation

/// Resolves a faction's crest + accent colour from the catalogue, honouring user overrides.
/// Ports `compositePresetKey`, `normalizeFactionLabel`, `resolveFactionPreset`,
/// `getArmyPresentation` from `js/data/factions/build.js`.
enum FactionResolver {
    static let fallbackColor = "#888"

    /// "Game:Faction" when both present, else the faction alone. Mirrors `compositePresetKey`.
    static func compositeKey(game: String, faction: String) -> String {
        let g = game.trimmingCharacters(in: .whitespaces)
        let f = faction.trimmingCharacters(in: .whitespaces)
        return (!g.isEmpty && !f.isEmpty) ? "\(g):\(f)" : f
    }

    // lowercase label/alias → canonical label
    private static let labelLC: [String: String] = {
        var map: [String: String] = [:]
        for d in FactionDefs.all {
            map[d.label.lowercased()] = d.label
            for a in d.aliases { map[a.lowercased()] = d.label }
        }
        for (alias, label) in FactionDefs.aliases {
            map[alias.lowercased()] = label
        }
        return map
    }()

    // composite "Game:Faction" → (crest, color)
    private static let compositeDefaults: [String: (String, String)] = {
        var map: [String: (String, String)] = [:]
        for d in FactionDefs.all {
            for game in d.games {
                map[compositeKey(game: game, faction: d.label)] = (d.crest, d.color)
            }
        }
        return map
    }()

    // flat label/alias → (crest, color)
    private static let flatDefaults: [String: (String, String)] = {
        var map: [String: (String, String)] = [:]
        for d in FactionDefs.all {
            map[d.label] = (d.crest, d.color)
            for a in d.aliases { map[a] = (d.crest, d.color) }
        }
        return map
    }()

    /// Canonicalize a possibly-aliased faction label. Mirrors `normalizeFactionLabel`.
    static func normalize(_ faction: String) -> String {
        let raw = faction.trimmingCharacters(in: .whitespaces)
        if raw.isEmpty { return "" }
        return FactionDefs.aliases[raw] ?? labelLC[raw.lowercased()] ?? raw
    }

    /// Faction labels per game, for the New Army picker. Mirrors `CANONICAL_FACTIONS`.
    static let canonicalByGame: [String: [String]] = {
        var map: [String: [String]] = [:]
        for d in FactionDefs.all {
            for game in d.games { map[game, default: []].append(d.label) }
        }
        return map
    }()

    /// Resolve (crest, color). Order: user override (composite) → catalogue composite (if
    /// game) → catalogue flat (if no game) → fallback (2-char uppercase + #888).
    static func resolve(faction: String,
                        game: String,
                        overrides: [FactionPresetOverride]) -> (crest: String, color: String) {
        let label = normalize(faction)
        let g = game.trimmingCharacters(in: .whitespaces)

        // User overrides take priority (keyed by composite).
        let overrideMap = Dictionary(overrides.map { ($0.key, ($0.crest, $0.hex)) },
                                     uniquingKeysWith: { _, new in new })
        if let o = overrideMap[compositeKey(game: g, faction: label)] {
            return (o.0, o.1)
        }

        if !g.isEmpty {
            if let hit = compositeDefaults[compositeKey(game: g, faction: label)] {
                return (hit.0, hit.1)
            }
        } else if let hit = flatDefaults[label] {
            return (hit.0, hit.1)
        }

        let abbr = label.isEmpty ? "??" : String(label.prefix(2)).uppercased()
        return (abbr, fallbackColor)
    }

    static func isFallback(_ color: String) -> Bool { color == fallbackColor }
}

extension Army {
    /// Displayed crest/colour: override wins, else resolved from the catalogue.
    /// Mirrors `getArmyPresentation`.
    func presentation(overrides: [FactionPresetOverride]) -> (crest: String, colorHex: String) {
        let r = FactionResolver.resolve(faction: faction, game: game, overrides: overrides)
        return (crestOverride ?? r.crest, safeColor(colorOverrideHex ?? r.color))
    }
}
