import SwiftUI
import SwiftData

/// Armies tab (M2 + M3): stats, meter, filters/search/sort, and editable army cards.
/// See `docs/ios-spec/03-armies.md` and `06-filters-search-sort.md`.
@MainActor
struct ArmiesScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Environment(UndoService.self) private var undo
    @Environment(AppRouter.self) private var router
    @Query(sort: \Army.sortIndex) private var armies: [Army]
    @Query private var configs: [AppConfiguration]

    @State private var showAddArmy = false
    @State private var showSettings = false
    @State private var search = ""

    private var cfg: AppConfiguration { configs.first ?? Config.current(context) }
    private var overrides: [FactionPresetOverride] { cfg.factionOverrides }
    private var globalPipeline: [PipelineStage]? { cfg.globalPipeline }
    private var resolvedGlobal: [PipelineStage] { Pipeline.resolve(globalPipeline) }
    private var armyNames: [String] { armies.map(\.name) }

    private var visible: [VisibleArmy] {
        ArmyFilter.build(armies: armies, cfg: cfg, search: search, global: globalPipeline)
    }
    private var scoped: Bool { ArmyFilter.isActive(cfg, search: search) }
    private var scopedUnits: [Unit] { scoped ? visible.flatMap(\.units) : armies.flatMap(\.units) }

    var body: some View {
        Group {
            if armies.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Armies")
        .toolbar { toolbarContent }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape") { showSettings = true }
            }
        }
        .dataPortToolbar(.armies)
        .sheet(isPresented: $showAddArmy) {
            AddArmySheet { game, faction, name in
                ArmyStore.addArmy(name: name, game: game, faction: faction, in: context)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsScreen() }
        .onAppear(perform: applyPendingSource)
        .onChange(of: router.pendingSourceFilter) { applyPendingSource() }
    }

    private func applyPendingSource() {
        guard let src = router.pendingSourceFilter else { return }
        router.pendingSourceFilter = nil
        let match = armies.flatMap { $0.units.map(\.source) }.first { SourceMatch.matches(src, $0) }
        cfg.sourceFilter = match ?? SourceMatch.parts(src).first ?? src
        cfg.quickViewRaw = "all"; cfg.gameFilter = "All"; cfg.factionFilter = "All"
        try? context.save()
    }

    @ViewBuilder private var content: some View {
        let vis = visible
        ScrollView {
            LazyVStack(spacing: 16) {
                ArmyStatsHeader(units: scopedUnits, armyCount: scoped ? vis.count : armies.count,
                                pipeline: resolvedGlobal, scoped: scoped)

                ArmyFilterBar(cfg: cfg, search: $search,
                              games: Array(Set(armies.map(\.game))).sorted(),
                              factions: Array(Set(armies.map(\.faction))).sorted(),
                              sources: ArmyFilter.allSources(armies),
                              states: ["All"] + resolvedGlobal.map(\.key),
                              tags: ArmyFilter.allNoteTags(armies),
                              overrides: overrides)

                if vis.isEmpty {
                    ContentUnavailableView {
                        Label("No matching units", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("Nothing matches your current search or filters.")
                    } actions: {
                        Button("Clear filters") {
                            ArmyFilter.clearFilters(cfg); search = ""
                        }.buttonStyle(.borderedProminent)
                    }
                } else {
                    ForEach(vis) { va in
                        ArmyCard(army: va.army, overrides: overrides,
                                 globalPipeline: globalPipeline, allArmyNames: armyNames,
                                 visibleUnits: va.units)
                    }
                }
            }
            .padding()
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button("New army", systemImage: "plus") { showAddArmy = true }
            Button("Undo", systemImage: "arrow.uturn.backward") {
                if let msg = undo.undo(in: context) { toast.show(msg) }
            }
            .disabled(!undo.canUndo)
            if !armies.isEmpty {
                Button("Advance visible", systemImage: "arrow.right.to.line") {
                    let n = ArmyStore.advanceUnits(visible.flatMap(\.units), global: globalPipeline, in: context)
                    toast.show(n > 0 ? "Advanced \(n) unit\(n == 1 ? "" : "s")" : "Nothing to advance")
                }
                Menu("View", systemImage: "rectangle.expand.vertical") {
                    Button("Expand all") { ArmyStore.setCollapseAll(false, in: context) }
                    Button("Collapse all") { ArmyStore.setCollapseAll(true, in: context) }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No armies yet", systemImage: "shield")
        } description: {
            Text("Import warhammer_armies.csv via the Data menu, add a new army, or load the sample collection. Then switch to the Paint Rack tab for paints.")
        } actions: {
            Button("Load sample data") {
                toast.show(DataActions.loadSample(ctx: context))
            }.buttonStyle(.borderedProminent)
            Button("New army") { showAddArmy = true }
        }
    }
}

#Preview("Empty") {
    NavigationStack { ArmiesScreen() }
        .modelContainer(AppContainer.previewContainer())
        .environment(ToastCenter())
        .environment(UndoService.shared)
        .environment(AppRouter())
}
