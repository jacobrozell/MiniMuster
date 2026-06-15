import SwiftUI

/// Lightweight cross-tab navigation/coordination.
@Observable
@MainActor
final class AppRouter {
    enum Tab: String { case armies, paints }
    var tab: Tab = .armies

    /// Pending source filter to apply on the Collection tab after switching.
    var pendingSourceFilter: String?

    /// Pending deep link to apply on the Collection tab after switching.
    var pendingDeepLink: AppDeepLink.Destination?

    /// Mirrors the Collection home search field so army detail respects active search.
    var collectionSearch: String = ""

    func showArmies(filteredBySource source: String) {
        pendingSourceFilter = source
        tab = .armies
    }

    func open(_ destination: AppDeepLink.Destination) {
        pendingDeepLink = destination
        tab = .armies
    }
}
