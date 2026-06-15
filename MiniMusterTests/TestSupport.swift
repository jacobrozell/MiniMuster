import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
@testable import MiniMuster

/// Retains an in-memory `ModelContainer` for the lifetime of a test. SwiftData contexts
/// must outlive their store; dropping the container while a context is still in use traps.
@MainActor
final class TestDatabase {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() { container = AppContainer.previewContainer() }
}

@MainActor
enum ViewTestHost {
    static func render<V: View>(_ view: V, container: ModelContainer? = nil) {
#if canImport(UIKit)
        let root: AnyView
        if let container {
            root = AnyView(view.modelContainer(container))
        } else {
            root = AnyView(view)
        }
        let host = UIHostingController(rootView: root)
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()
#else
        _ = view
        _ = container
#endif
    }

    static func appEnvironments<V: View>(_ view: V) -> some View {
        view
            .environment(BannerCenter())
            .environment(UndoService.shared)
            .environment(AppRouter())
    }
}
