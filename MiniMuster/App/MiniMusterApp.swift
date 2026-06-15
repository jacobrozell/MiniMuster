import SwiftUI
import SwiftData
import TipKit

@main
struct MiniMusterApp: App {
    let container: ModelContainer
    @State private var banner = BannerCenter()
    @State private var undo = UndoService.shared

    init() {
        if ProcessInfo.processInfo.arguments.contains("UI-Testing-ResetPersistent") {
            AppContainer.resetUITestPersistentStore()
        }
        if ProcessInfo.processInfo.arguments.contains("UI-Testing-Persistent") {
            container = AppContainer.uiTestPersistentContainer()
        } else if ProcessInfo.processInfo.arguments.contains("UI-Testing") {
            container = AppContainer.previewContainer()
        } else {
            container = AppContainer.make()
        }
        configureTips()
    }

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environment(banner)
                .environment(undo)
        }
        .modelContainer(container)
    }

    private func configureTips() {
        do {
            if AppInfo.isUITesting {
                try Tips.resetDatastore()
                try Tips.configure([.displayFrequency(.immediate)])
                Tips.hideAllTipsForTesting()
            } else {
                try Tips.configure([.displayFrequency(.immediate)])
            }
        } catch {
            // TipKit is best-effort; the app must still launch if configuration fails.
        }
    }
}
