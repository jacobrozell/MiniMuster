import SwiftUI
import SwiftData

/// Muster tab with adaptive split view (iPad) and navigation stack (iPhone).
struct MusterTab: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query private var configs: [AppConfiguration]

    @State private var selectedRosterId: UUID?
    @State private var compactPath = NavigationPath()
    @State private var showMusterIntro = false

    private var usesSplitLayout: Bool {
        AdaptiveLayout.usesSplitNavigation(horizontalSizeClass)
    }

    private var sidebarWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) {
        AdaptiveLayout.splitColumnWidth(dynamicType: dynamicTypeSize)
    }

    var body: some View {
        Group {
            if usesSplitLayout { splitView }
            else { compactView }
        }
        .onAppear {
            UnitCatalogLoader.loadIfNeeded()
            consumePendingRoster()
            checkMusterIntro()
        }
        .onChange(of: router.pendingRosterId) { _, _ in consumePendingRoster() }
        .onChange(of: router.selectedRosterId) { _, id in
            if let id { selectedRosterId = id }
        }
        .sheet(isPresented: $showMusterIntro) {
            MusterIntroSheet {
                if let cfg = configs.first {
                    cfg.hasSeenMusterIntro = true
                    try? context.save()
                }
                showMusterIntro = false
            }
        }
    }

    private var splitView: some View {
        NavigationSplitView {
            NavigationStack {
                MusterHomeView(selectedRosterId: $selectedRosterId) { id in
                    selectedRosterId = id
                    router.selectedRosterId = id
                }
            }
            .navigationSplitViewColumnWidth(min: sidebarWidth.min, ideal: sidebarWidth.ideal, max: sidebarWidth.max)
        } detail: {
            NavigationStack {
                Group {
                    if let rosterId = selectedRosterId ?? router.selectedRosterId {
                        RosterEditorView(rosterId: rosterId)
                    } else {
                        ContentUnavailableView("Select a list", systemImage: "flag",
                                               description: Text("Choose a roster from the list."))
                    }
                }
            }
        }
    }

    private var compactView: some View {
        NavigationStack(path: $compactPath) {
            MusterHomeView(selectedRosterId: $selectedRosterId) { id in
                selectedRosterId = id
                compactPath.append(MusterRoute.roster(id))
            }
            .navigationDestination(for: MusterRoute.self) { route in
                if case .roster(let id) = route {
                    RosterEditorView(rosterId: id)
                }
            }
        }
    }

    private func consumePendingRoster() {
        guard let id = router.pendingRosterId else { return }
        router.pendingRosterId = nil
        selectedRosterId = id
        router.selectedRosterId = id
        if !usesSplitLayout {
            compactPath.append(MusterRoute.roster(id))
        }
    }

    private func checkMusterIntro() {
        guard !AppInfo.isUITesting else { return }
        guard let cfg = configs.first, cfg.hasSeenOnboarding, !cfg.hasSeenMusterIntro else { return }
        showMusterIntro = true
    }
}
