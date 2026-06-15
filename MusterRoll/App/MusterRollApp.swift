import SwiftUI
import SwiftData

@main
struct MusterRollApp: App {
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
    }

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environment(banner)
                .environment(undo)
        }
        .modelContainer(container)
    }
}
