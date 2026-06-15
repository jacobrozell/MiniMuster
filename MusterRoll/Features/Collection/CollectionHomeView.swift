import SwiftUI
import SwiftData

/// Browse all armies; search and filter without inline unit editing.
@MainActor
struct CollectionHomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var context
    @Environment(BannerCenter.self) private var banner
    @Environment(UndoService.self) private var undo
    @Environment(AppRouter.self) private var router
    @Query(sort: \Army.sortIndex) private var armies: [Army]
    @Query private var configs: [AppConfiguration]

    @Binding var selectedArmyId: UUID?
    var onSelectArmy: (UUID) -> Void = { _ in }

    @State private var showAddArmy = false
    @State private var showSettings = false
    @State private var showFilters = false
    @State private var search = ""
    @State private var armyToDelete: Army?
    @State private var armyToRename: Army?
    @State private var loadSampleError: (title: String, message: String)?
    @State private var filterTrigger = false
    @State private var deleteWarningTrigger = false

    init(selectedArmyId: Binding<UUID?>, onSelectArmy: @escaping (UUID) -> Void = { _ in }) {
        _selectedArmyId = selectedArmyId
        self.onSelectArmy = onSelectArmy
    }

    private var cfg: AppConfiguration { configs.first ?? Config.current(context) }
    private var overrides: [FactionPresetOverride] { cfg.factionOverrides }
    private var globalPipeline: [PipelineStage]? { cfg.globalPipeline }
    private var scoped: Bool { ArmyFilter.isActive(cfg, search: search) }
    private var filterCount: Int { ArmyFilter.activeFilterCount(cfg) }

    private var visible: [VisibleArmy] {
        ArmyFilter.build(armies: armies, cfg: cfg, search: search, global: globalPipeline)
    }

    private var usesPadSidebarList: Bool {
        AdaptiveLayout.usesSidebarListStyle(horizontalSizeClass)
    }

    var body: some View {
        Group {
            if armies.isEmpty { emptyState }
            else { listContent }
        }
        .navigationTitle("Collection")
        .searchable(text: $search, prompt: "Armies, factions, units…")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAddArmy) {
            AddArmySheet { game, faction, name in
                ArmyStore.addArmy(name: name, game: game, faction: faction, in: context)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsScreen() }
        .sheet(isPresented: $showFilters) {
            FilterSheet(cfg: cfg,
                        games: Array(Set(armies.map(\.game))).sorted(),
                        factions: Array(Set(armies.map(\.faction))).sorted(),
                        sources: ArmyFilter.allSources(armies),
                        states: ["All"] + Pipeline.resolve(globalPipeline).map(\.key),
                        tags: ArmyFilter.allNoteTags(armies),
                        overrides: overrides)
        }
        .sheet(isPresented: Binding(
            get: { armyToRename != nil },
            set: { if !$0 { armyToRename = nil } }
        )) {
            if let army = armyToRename {
                RenameArmySheet(current: army.name) { ArmyStore.rename(army, to: $0, in: context) }
                    .presentationDetents([.medium])
            }
        }
        .alert(loadSampleError?.title ?? "Error", isPresented: Binding(
            get: { loadSampleError != nil },
            set: { if !$0 { loadSampleError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let loadSampleError { Text(loadSampleError.message) }
        }
        .sensoryFeedback(.selection, trigger: filterTrigger)
        .sensoryFeedback(.warning, trigger: deleteWarningTrigger)
        .onAppear {
            applyPendingSource()
            router.collectionSearch = search
        }
        .onChange(of: search) { router.collectionSearch = search }
        .onChange(of: router.pendingSourceFilter) { applyPendingSource() }
        .confirmationDialog(
            "Delete entire army \"\(armyToDelete?.name ?? "")\" and all its units?",
            isPresented: Binding(get: { armyToDelete != nil }, set: { if !$0 { armyToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let army = armyToDelete {
                    if army.id == selectedArmyId { selectedArmyId = nil }
                    ArmyStore.delete(army, in: context)
                    deleteWarningTrigger.toggle()
                }
                armyToDelete = nil
            }
            Button("Cancel", role: .cancel) { armyToDelete = nil }
        }
    }

    @ViewBuilder private var listContent: some View {
        let vis = visible
        if vis.isEmpty {
            ContentUnavailableView {
                Label("No matching units", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("Nothing matches your current search or filters.")
            } actions: {
                Button("Clear filters") { clearFilters() }.buttonStyle(.borderedProminent)
            }
        } else {
            armyList
        }
    }

    @ViewBuilder private var armyList: some View {
        let vis = visible
        let list = List {
            if scoped {
                Section {
                    HStack {
                        Label(filterBannerText, systemImage: "line.3.horizontal.decrease.circle")
                            .font(.subheadline)
                        Spacer()
                        Button("Clear") { clearFilters() }.font(.subheadline)
                    }
                }
            }
            Section {
                ForEach(vis) { va in
                    let pipeline = Pipeline.forArmy(va.army, global: globalPipeline)
                    let pct = Int((Pipeline.progress(of: va.units, pipeline) * 100).rounded())
                    Button {
                        selectedArmyId = va.army.id
                        onSelectArmy(va.army.id)
                    } label: {
                        ArmyRow(army: va.army, overrides: overrides,
                                visibleUnitCount: va.units.count,
                                percentComplete: pct, scoped: scoped)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("army-\(va.army.name)")
                    .listRowBackground(va.army.id == selectedArmyId ? Color.accentColor.opacity(0.12) : nil)
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") { armyToRename = va.army }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            armyToDelete = va.army
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) { armyToDelete = va.army }
                            .accessibilityLabel("Delete army")
                    }
                }
            }
        }
        if usesPadSidebarList {
            list.listStyle(.sidebar)
        } else {
            list.listStyle(.insetGrouped)
        }
    }

    private var filterBannerText: String {
        var parts: [String] = []
        if filterCount > 0 { parts.append("\(filterCount) filter\(filterCount == 1 ? "" : "s")") }
        if !search.isEmpty { parts.append("search") }
        return parts.isEmpty ? "Filters active" : parts.joined(separator: " · ")
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button("New army", systemImage: "plus") { showAddArmy = true }
            Button("Undo", systemImage: "arrow.uturn.backward") {
                if let msg = undo.undo(in: context) { banner.show(msg) }
            }
            .disabled(!undo.canUndo)
            .accessibilityLabel("Undo")
            .accessibilityHint(undo.canUndo ? "Reverts the last action" : "No actions to undo")
        }
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(value: CollectionRoute.overview) {
                Label("Overview", systemImage: "chart.pie")
            }
            .labelStyle(.iconOnly)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Filters", systemImage: filterCount > 0 || scoped
                   ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") {
                showFilters = true
            }
            .accessibilityLabel(filterCount > 0 ? "Filters, \(filterCount) active" : "Filters")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Settings", systemImage: "gearshape") { showSettings = true }
                .accessibilityIdentifier("settings")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No armies yet", systemImage: "shield")
        } description: {
            Text("Add a new army or load the sample collection from Settings → Data.")
        } actions: {
            Button("Load sample data") { loadSample() }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("loadSampleData")
            Button("New army") { showAddArmy = true }
        }
        .safeAreaPadding(.bottom, 72)
    }

    private func clearFilters() {
        ArmyFilter.clearFilters(cfg)
        search = ""
        router.collectionSearch = ""
        try? context.save()
    }

    private func applyPendingSource() {
        guard let src = router.pendingSourceFilter else { return }
        router.pendingSourceFilter = nil
        let match = armies.flatMap { $0.units.map(\.source) }.first { SourceMatch.matches(src, $0) }
        cfg.sourceFilter = match ?? SourceMatch.parts(src).first ?? src
        cfg.quickViewRaw = "all"
        cfg.gameFilter = "All"
        cfg.factionFilter = "All"
        try? context.save()
        banner.show("Filtered by source: \(cfg.sourceFilter)")
        filterTrigger.toggle()
    }

    private func loadSample() {
        let outcome = DataActions.loadSampleOutcome(ctx: context)
        if outcome.success {
            banner.show(outcome.message)
        } else {
            loadSampleError = (outcome.title, outcome.message)
        }
    }
}

#Preview {
    CollectionTab()
        .modelContainer(AppContainer.previewContainer())
        .environment(BannerCenter())
        .environment(UndoService.shared)
        .environment(AppRouter())
}
