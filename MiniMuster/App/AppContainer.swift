import Foundation
import SwiftData

/// SwiftData container factory. Mirrors the role of `js/core/store.js` load/persist setup.
enum AppContainer {
    static let schema = Schema([
        Army.self, Unit.self, SquadMember.self, Paint.self, AppConfiguration.self,
    ])

    /// On-disk container for the running app.
    @MainActor
    static func make() -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            ensureConfiguration(container.mainContext)
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// In-memory container for previews and tests.
    @MainActor
    static func previewContainer(seeded: Bool = false) -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            ensureConfiguration(container.mainContext)
            // Seeding hook: DemoLoader (M5) will populate from bundled sample CSVs.
            return container
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }

    /// On-disk temp container for UI tests that need persistence across relaunches.
    @MainActor
    static func uiTestPersistentContainer() -> ModelContainer {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "MiniMusterUITest-Persistent", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appending(path: "store.sqlite")
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            ensureConfiguration(container.mainContext)
            return container
        } catch {
            fatalError("Failed to create UI test ModelContainer: \(error)")
        }
    }

    /// Remove the on-disk UI test store (call from UI test setUp for a fresh install).
    static func resetUITestPersistentStore() {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "MiniMusterUITest-Persistent", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)
    }

    /// Guarantee exactly one AppConfiguration row exists.
    @MainActor
    static func ensureConfiguration(_ context: ModelContext) {
        let existing = try? context.fetch(FetchDescriptor<AppConfiguration>())
        if existing?.isEmpty ?? true {
            context.insert(AppConfiguration())
            try? context.save()
        }
        if ProcessInfo.processInfo.arguments.contains("UI-Testing-DarkTheme"),
           let cfg = try? context.fetch(FetchDescriptor<AppConfiguration>()).first {
            cfg.theme = .dark
            try? context.save()
        }
    }
}

/// Fetch the single AppConfiguration row, creating it if absent. Replaces `settings` access.
enum Config {
    @MainActor
    static func current(_ context: ModelContext) -> AppConfiguration {
        if let found = try? context.fetch(FetchDescriptor<AppConfiguration>()).first {
            return found
        }
        let cfg = AppConfiguration()
        context.insert(cfg)
        return cfg
    }
}
