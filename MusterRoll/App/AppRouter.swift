import SwiftUI

/// Lightweight cross-tab navigation/coordination. Lets the Paint Rack deep-link into the
/// Armies tab filtered by a paint's source (mirrors the web `muster:filter-source` event).
@Observable
@MainActor
final class AppRouter {
    enum Tab: String { case armies, paints }
    var tab: Tab = .armies

    /// Pending source filter to apply on the Armies tab after switching.
    var pendingSourceFilter: String?

    func showArmies(filteredBySource source: String) {
        pendingSourceFilter = source
        tab = .armies
    }
}
