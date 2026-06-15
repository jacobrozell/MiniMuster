import Foundation
import SwiftData

/// Single-row settings entity. Replaces the web `settings` object (`js/core/constants.js`,
/// `js/core/store.js`). Access via `Config.current(_:)`, which creates it if absent.
@Model
final class AppConfiguration {
    var id: UUID = UUID()

    // Theme: "dark" | "light" | "system". iOS default is "system" (web default was "dark").
    var themeRaw: String = ThemePreference.system.rawValue

    /// Global pipeline override. nil = use DefaultPipeline.
    var globalPipeline: [PipelineStage]?

    /// User faction crest/colour overrides, keyed "Game:Faction".
    var factionOverrides: [FactionPresetOverride] = []

    // Armies-tab filter / sort prefs.
    var gameFilter: String = "All"
    var factionFilter: String = "All"
    var stateFilter: String = "All"
    var sourceFilter: String = "All"
    var tagFilter: String = "All"
    var spearheadOnly: Bool = false
    var quickViewRaw: String = "all"      // all | backlog | wip | ready
    var armySortRaw: String = "import"    // import | name | progress (web "csv" == "import")
    var unitSortRaw: String = "name"      // name | state

    // Paint-tab filter prefs.
    var paintTypeFilter: String = "All"
    var paintBrandFilter: String = "All"
    var paintLowOnly: Bool = false

    var lastBackupAt: Date?

    /// One-time welcome flow; set on dismiss. Existing installs with data auto-skip.
    var hasSeenOnboarding: Bool = false

    /// One-time Muster tab intro for upgrades after 1.2.
    var hasSeenMusterIntro: Bool = false
    var defaultBattleSizeKey40k: String = "strike-force"

    init() {}
}

extension AppConfiguration {
    var theme: ThemePreference {
        get { ThemePreference(rawValue: themeRaw) ?? .system }
        set { themeRaw = newValue.rawValue }
    }
}

/// Theme preference cycling dark → light → system. Ports `js/ui/theme.js`.
enum ThemePreference: String, CaseIterable, Sendable {
    case dark, light, system

    var next: ThemePreference {
        switch self {
        case .dark: .light
        case .light: .system
        case .system: .dark
        }
    }

    var label: String { rawValue.capitalized }
}
