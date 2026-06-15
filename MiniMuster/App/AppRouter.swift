import SwiftUI

/// Lightweight cross-tab navigation/coordination.
@Observable
@MainActor
final class AppRouter {
    enum Tab: String { case armies, muster, paints }
    var tab: Tab = .armies

    /// Pending source filter to apply on the Collection tab after switching.
    var pendingSourceFilter: String?

    /// Pending deep link to apply on the Collection tab after switching.
    var pendingDeepLink: AppDeepLink.Destination?

    /// Mirrors the Collection home search field so army detail respects active search.
    var collectionSearch: String = ""

    // Muster
    var musterSearch: String = ""
    var pendingRosterId: UUID?
    var selectedRosterId: UUID?

    var pendingCollectionArmyId: UUID?
    var pendingCollectionUnitId: UUID?

    func showArmies(filteredBySource source: String) {
        pendingSourceFilter = source
        tab = .armies
    }

    func open(_ destination: AppDeepLink.Destination) {
        switch destination {
        case .collectionBacklog:
            pendingDeepLink = destination
            tab = .armies
        case .musterHome:
            tab = .muster
        case .musterRoster(let id):
            openMuster(rosterId: id)
        }
    }

    func openMuster(rosterId: UUID) {
        pendingRosterId = rosterId
        selectedRosterId = rosterId
        tab = .muster
    }

    func openCollection(armyId: UUID, unitId: UUID? = nil) {
        tab = .armies
        pendingCollectionArmyId = armyId
        pendingCollectionUnitId = unitId
    }
}
