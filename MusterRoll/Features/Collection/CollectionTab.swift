import SwiftUI
import SwiftData

/// Collection tab with adaptive split view (iPad) and navigation stack (iPhone).
struct CollectionTab: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedArmyId: UUID?
    @State private var selectedUnitId: UUID?
    @State private var compactPath = NavigationPath()
    @State private var detailPath = NavigationPath()

    private var usesSplitLayout: Bool {
        AdaptiveLayout.usesSplitNavigation(horizontalSizeClass)
    }

    private var sidebarWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) {
        AdaptiveLayout.splitColumnWidth(dynamicType: dynamicTypeSize)
    }

    var body: some View {
        Group {
            if usesSplitLayout {
                splitView
            } else {
                compactView
            }
        }
        .onChange(of: selectedArmyId) { _, _ in
            selectedUnitId = nil
            detailPath = NavigationPath()
        }
        .onChange(of: detailPath) { _, path in
            if path.isEmpty { selectedUnitId = nil }
        }
    }

    /// iPad: armies in the sidebar; army + unit detail share one navigation stack (no empty third column).
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
            .navigationSplitViewColumnWidth(min: sidebarWidth.min, ideal: sidebarWidth.ideal, max: sidebarWidth.max)
        } detail: {
            NavigationStack(path: $detailPath) {
                Group {
                    if let armyId = selectedArmyId {
                        ArmyDetailView(armyId: armyId, selectedArmyId: $selectedArmyId,
                                       selectedUnitId: $selectedUnitId,
                                       onSelectUnit: { unitId in
                                           selectedUnitId = unitId
                                           detailPath.append(CollectionRoute.unit(unitId))
                                       })
                    } else {
                        ContentUnavailableView("Select an Army", systemImage: "shield",
                                               description: Text("Choose an army from the list."))
                    }
                }
                .navigationDestination(for: CollectionRoute.self) { route in
                    switch route {
                    case .unit(let unitId):
                        UnitDetailView(unitId: unitId)
                    case .overview:
                        CollectionOverviewView()
                    case .army:
                        EmptyView()
                    }
                }
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
                    ArmyDetailView(armyId: armyId, selectedArmyId: $selectedArmyId,
                                   selectedUnitId: $selectedUnitId,
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
