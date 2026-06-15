import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Collection tab with adaptive split view (iPad) and navigation stack (iPhone).
struct CollectionTab: View {
    @State private var selectedArmyId: UUID?
    @State private var selectedUnitId: UUID?
    @State private var compactPath = NavigationPath()

    private var usesSplitLayout: Bool {
#if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
#else
        false
#endif
    }

    var body: some View {
        Group {
            if usesSplitLayout {
                splitView
            } else {
                compactView
            }
        }
        .onChange(of: selectedArmyId) { _, _ in selectedUnitId = nil }
    }

    private var splitView: some View {
        NavigationSplitView {
            NavigationStack {
                CollectionHomeView(
                    selectedArmyId: $selectedArmyId,
                    onSelectArmy: { selectedArmyId = $0 }
                )
                .navigationDestination(for: CollectionRoute.self) { route in
                    if case .overview = route {
                        CollectionOverviewView()
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        } content: {
            if let armyId = selectedArmyId {
                ArmyDetailView(armyId: armyId, selectedUnitId: $selectedUnitId,
                               onSelectUnit: { selectedUnitId = $0 })
            } else {
                ContentUnavailableView("Select an Army", systemImage: "shield",
                                       description: Text("Choose an army from the list."))
            }
        } detail: {
            if let unitId = selectedUnitId {
                UnitDetailView(unitId: unitId)
            } else if selectedArmyId != nil {
                ContentUnavailableView("Select a Unit", systemImage: "figure.stand",
                                       description: Text("Choose a unit to view and edit."))
            } else {
                ContentUnavailableView("No Selection", systemImage: "sidebar.left")
            }
        }
    }

    private var compactView: some View {
        NavigationStack(path: $compactPath) {
            CollectionHomeView(
                selectedArmyId: $selectedArmyId,
                onSelectArmy: { armyId in
                    selectedArmyId = armyId
                    compactPath.append(CollectionRoute.army(armyId))
                }
            )
            .navigationDestination(for: CollectionRoute.self) { route in
                switch route {
                case .overview:
                    CollectionOverviewView()
                case .army(let armyId):
                    ArmyDetailView(armyId: armyId, selectedUnitId: $selectedUnitId,
                                   onSelectUnit: { unitId in
                                       selectedUnitId = unitId
                                       compactPath.append(CollectionRoute.unit(unitId))
                                   })
                case .unit(let unitId):
                    UnitDetailView(unitId: unitId)
                }
            }
        }
    }
}
