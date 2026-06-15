import Foundation

/// Shared snapshot keys for the home-screen widget (App Group).
enum WidgetDataStore {
    static let appGroupID = "group.com.jacobrozell.minimuster"
    private static let sprueKey = "sprueModelCount"
    private static let totalKey = "totalModelCount"

    static func write(sprueModelCount: Int, totalModelCount: Int) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(sprueModelCount, forKey: sprueKey)
        defaults.set(totalModelCount, forKey: totalKey)
    }

    static var sprueModelCount: Int {
        UserDefaults(suiteName: appGroupID)?.integer(forKey: sprueKey) ?? 0
    }

    static var totalModelCount: Int {
        UserDefaults(suiteName: appGroupID)?.integer(forKey: totalKey) ?? 0
    }
}
