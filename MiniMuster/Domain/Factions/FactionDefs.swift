import Foundation

/// Supported game systems. Ports `SUPPORTED_GAMES` (`js/data/factions/games.js`).
enum SupportedGames {
    static let all = ["40k", "AoS", "TOW", "30k", "Necromunda", "Warcry", "Blood Bowl", "MESBG"]
}

/// One faction catalogue entry. Ports the `FactionDef` typedef (`js/data/factions/defs.js`).
struct FactionDef: Hashable, Sendable {
    let label: String
    let crest: String
    let color: String
    let games: [String]
    let aliases: [String]

    init(_ label: String, _ crest: String, _ color: String,
         _ games: [String], aliases: [String] = []) {
        self.label = label
        self.crest = crest
        self.color = color
        self.games = games
        self.aliases = aliases
    }
}

/// The faction catalogue, ported verbatim from `js/data/factions/defs-40k.js`,
/// `defs-aos.js`, `defs-other.js`, and `aliases.js`.
enum FactionDefs {
    private static let k40 = ["40k"]
    private static let aos = ["AoS"]
    private static let tow = ["TOW"]
    private static let h30 = ["30k"]
    private static let necro = ["Necromunda"]
    private static let warcry = ["Warcry"]
    private static let bb = ["Blood Bowl"]
    private static let mesbg = ["MESBG"]

    static let fortyK: [FactionDef] = [
        .init("Adepta Sororitas", "SOR", "#c41e3a", k40, aliases: ["Sisters of Battle"]),
        .init("Blood Angels", "BA", "#9b1c1c", k40),
        .init("Dark Angels", "DA", "#1e4d2b", k40),
        .init("Deathwatch", "DW", "#3d4349", k40),
        .init("Grey Knights", "GK", "#aeb6bd", k40),
        .init("Space Marines", "SM", "#1c4fa0", k40),
        .init("Ultramarines", "UM", "#1c4fa0", k40),
        .init("Space Wolves", "SW", "#4a6fa5", k40),
        .init("Black Templars", "BT", "#1c1c1c", k40),
        .init("World Eaters", "WE", "#b81c1c", k40),
        .init("Emperor's Children", "EC", "#b060a8", k40),
        .init("Leagues of Votann", "VOT", "#c4682a", k40, aliases: ["Votann"]),
        .init("Adeptus Custodes", "AC", "#d4af37", k40),
        .init("Adeptus Mechanicus", "AdM", "#8b1a1a", k40),
        .init("Agents of Imperium", "AOI", "#5a6a7a", k40),
        .init("Aeldari", "AE", "#2d8b83", k40, aliases: ["Eldar"]),
        .init("Astra Militarum", "IG", "#5c6b3a", k40, aliases: ["Imperial Guard"]),
        .init("Chaos Daemons", "CD", "#6b2d8b", k40),
        .init("Chaos Knights", "CK", "#4a1010", k40),
        .init("Drukhari", "DRU", "#4a148c", k40, aliases: ["Dark Eldar"]),
        .init("Chaos Space Marines", "CSM", "#5c1010", k40),
        .init("Death Guard", "DG", "#6b7a3a", k40),
        .init("Thousand Sons", "TS", "#1a6b8a", k40),
        .init("Genestealer Cults", "GSC", "#7b2d8b", k40),
        .init("Harlequins", "HAR", "#e91e8c", k40),
        .init("Imperial Knights", "IK", "#1c3a5c", k40),
        .init("Necrons", "NC", "#1a5c3a", k40),
        .init("Orks", "ORK", "#2d6b2d", k40),
        .init("T'au Empire", "TAU", "#c47b5a", k40, aliases: ["T'au"]),
        .init("Tyranids", "TYR", "#4a2d6b", k40),
    ]

    static let aosDefs: [FactionDef] = [
        .init("Stormcast Eternals", "SC", "#d4af37", aos),
        .init("Cities of Sigmar", "COS", "#6b5c4a", aos),
        .init("Lumineth Realm-lords", "LR", "#7ec8c8", aos),
        .init("Sylvaneth", "SYL", "#3d7a3a", aos),
        .init("Daughters of Khaine", "DOK", "#8b1a4a", aos),
        .init("Idoneth Deepkin", "ID", "#1a6b7a", aos),
        .init("Fyreslayers", "FY", "#e85c1a", aos),
        .init("Kharadron Overlords", "KO", "#b8860b", aos),
        .init("Seraphon", "SER", "#2a8a7a", aos),
        .init("Skaven", "SK", "#8a9a4a", aos),
        .init("Slaves to Darkness", "S2D", "#4a3d35", aos),
        .init("Blades of Khorne", "BK", "#b01010", aos),
        .init("Maggotkin of Nurgle", "NUR", "#5a7a3a", aos),
        .init("Hedonites of Slaanesh", "HOS", "#c45ab0", aos),
        .init("Disciples of Tzeentch", "DOT", "#2a5cb0", aos),
        .init("Soulblight Gravelords", "SB", "#6b1a2a", aos),
        .init("Ossiarch Bonereapers", "OB", "#d4cfc4", aos),
        .init("Nighthaunt", "NH", "#7ab8c8", aos),
        .init("Flesh-eater Courts", "FEC", "#c9a227", aos),
        .init("Ironjawz", "IJ", "#3d6b3a", aos),
        .init("Kruleboyz", "KB", "#4a6b4a", aos),
        .init("Gloomspite Gitz", "GG", "#7a4ab0", aos),
        .init("Sons of Behemat", "SOB", "#8a7355", aos),
        .init("Ogor Mawtribes", "OM", "#a08050", aos),
    ]

    static let other: [FactionDef] = [
        .init("Kingdom of Bretonnia", "BRE", "#1e4a8a", tow, aliases: ["Bretonnia"]),
        .init("Grand Cathay", "CAT", "#8b1a1a", tow),
        .init("Dwarfs", "DWF", "#5a4a35", tow),
        .init("High Elf Realms", "HE", "#2a6a9a", tow),
        .init("The Empire", "EMP", "#1a3a6b", tow),
        .init("Orc & Goblin Tribes", "O&G", "#3d7a2a", tow),
        .init("Tomb Kings of Khemri", "TK", "#c9a227", tow),
        .init("Warriors of Chaos", "WOC", "#4a1010", tow),
        .init("Wood Elf Realms", "WEW", "#3d8a3a", tow),
        .init("Beastmen Brayherds", "BM", "#5a4a3a", tow),
        .init("Daemons of Chaos", "DOC", "#6b2d8b", tow),
        .init("Legiones Astartes", "LA", "#4a5a6b", h30),
        .init("Mechanicum", "MECH", "#8b1a1a", h30),
        .init("Solar Auxilia", "SA", "#6b5c4a", h30),
        .init("Agents of the Emperor", "AOTE", "#d4af37", h30),
        .init("House Delaque", "DEL", "#3d4a6b", necro),
        .init("House Escher", "ESC", "#c45ab0", necro),
        .init("House Goliath", "GOL", "#c41e1a", necro),
        .init("House Orlock", "ORL", "#8a7355", necro),
        .init("House Van Saar", "VS", "#4a8ab0", necro),
        .init("House Cawdor", "CAW", "#c4682a", necro),
        .init("Palanite Enforcers", "ENF", "#2a4a7a", necro),
        .init("Corpse Grinder Cult", "CGC", "#8b1010", necro),
        .init("Warcry: Chaos", "WC", "#5c1010", warcry),
        .init("Warcry: Order", "WO", "#d4af37", warcry),
        .init("Warcry: Destruction", "WD", "#3d6b3a", warcry),
        .init("Warcry: Death", "WDE", "#7ab8c8", warcry),
        .init("Blood Bowl: Humans", "BBH", "#c9a86a", bb),
        .init("Blood Bowl: Orcs", "BBO", "#2d6b2d", bb),
        .init("Blood Bowl: Skaven", "BBS", "#8a9a4a", bb),
        .init("Blood Bowl: Chaos", "BBC", "#5c1010", bb),
        .init("Blood Bowl: Dark Elves", "BBDE", "#4a148c", bb),
        .init("Blood Bowl: Dwarfs", "BBD", "#5a4a35", bb),
        .init("Gondor", "GON", "#2a4a7a", mesbg),
        .init("Rohan", "ROH", "#8a7355", mesbg),
        .init("Mordor", "MOR", "#1a1a1a", mesbg),
        .init("Isengard", "ISN", "#5a5a5a", mesbg),
        .init("Lothlórien", "LOT", "#3d8a5a", mesbg),
        .init("Angmar", "ANG", "#4a6a8a", mesbg),
        .init("Terrain", "TR", "#8a8278", SupportedGames.all),
    ]

    static let all: [FactionDef] = fortyK + aosDefs + other

    /// Legacy / alternate CSV labels → canonical label. Ports `FACTION_ALIASES`.
    static let aliases: [String: String] = [
        "Heretic Astartes: Death Guard": "Death Guard",
        "Heretic Astartes: Thousand Sons": "Thousand Sons",
        "Heretic Astartes: World Eaters": "World Eaters",
        "Heretic Astartes: Emperor's Children": "Emperor's Children",
        "Adeptus Astartes: Blood Angels": "Blood Angels",
        "Adeptus Astartes: Dark Angels": "Dark Angels",
        "Adeptus Astartes: Deathwatch": "Deathwatch",
        "Adeptus Astartes: Grey Knights": "Grey Knights",
        "Adeptus Astartes: Space Marines": "Space Marines",
        "Adeptus Astartes: Space Wolves": "Space Wolves",
        "Adeptus Astartes: Black Templars": "Black Templars",
    ]
}
