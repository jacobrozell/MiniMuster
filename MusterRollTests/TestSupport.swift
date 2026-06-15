import SwiftData
@testable import MusterRoll

/// Retains an in-memory `ModelContainer` for the lifetime of a test. SwiftData contexts
/// must outlive their store; dropping the container while a context is still in use traps.
@MainActor
final class TestDatabase {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() { container = AppContainer.previewContainer() }
}
