import SwiftUI
import SwiftData

@main
struct MusterRollApp: App {
    let container: ModelContainer
    @State private var toast = ToastCenter()
    @State private var undo = UndoService.shared

    init() {
        container = AppContainer.make()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(toast)
                .environment(undo)
                .toastOverlay()
        }
        .modelContainer(container)
    }
}
