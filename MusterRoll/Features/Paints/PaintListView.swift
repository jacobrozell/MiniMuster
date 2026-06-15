import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

@MainActor
struct PaintListView: View {
    @Environment(\.modelContext) private var context
    @Environment(BannerCenter.self) private var banner
    @Environment(AppRouter.self) private var router
    @Query(sort: \Paint.name) private var paints: [Paint]
    @Query private var armies: [Army]
    @Query private var configs: [AppConfiguration]

    @Binding var selectedPaintId: UUID?
    var onSelectPaint: (UUID) -> Void = { _ in }

    @State private var search = ""
    @State private var showAdd = false
    @State private var showSettings = false
    @State private var showFilters = false
    @AppStorage("paintUseGrid") private var useGrid = false
    @State private var filterTrigger = false
    @State private var paintToDelete: Paint?
    @State private var deleteWarningTrigger = false

    init(selectedPaintId: Binding<UUID?>, onSelectPaint: @escaping (UUID) -> Void = { _ in }) {
        _selectedPaintId = selectedPaintId
        self.onSelectPaint = onSelectPaint
    }

    private var cfg: AppConfiguration { configs.first ?? Config.current(context) }
    private var types: [String] { Array(Set(paints.map(\.type).filter { !$0.isEmpty })).sorted() }
    private var brands: [String] { Array(Set(paints.map(\.brand).filter { !$0.isEmpty })).sorted() }

    private var filtersActive: Bool {
        cfg.paintTypeFilter != "All" || cfg.paintBrandFilter != "All" || cfg.paintLowOnly
    }

    private var filterCount: Int {
        var count = 0
        if cfg.paintTypeFilter != "All" { count += 1 }
        if cfg.paintBrandFilter != "All" { count += 1 }
        if cfg.paintLowOnly { count += 1 }
        return count
    }

    private var filtered: [Paint] {
        let q = search.lowercased()
        return paints.filter { p in
            (!cfg.paintLowOnly || p.low)
            && (cfg.paintTypeFilter == "All" || p.type == cfg.paintTypeFilter)
            && (cfg.paintBrandFilter == "All" || p.brand == cfg.paintBrandFilter)
            && (q.isEmpty || "\(p.name) \(p.type) \(p.brand) \(p.source) \(p.notes)".lowercased().contains(q))
        }
    }

    private var usesPadSidebarList: Bool {
#if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
#else
        false
#endif
    }

    var body: some View {
        Group {
            if paints.isEmpty { emptyState }
            else if filtered.isEmpty { noMatches }
            else if useGrid { gridBody }
            else { listBody }
        }
        .navigationTitle("Paints")
        .searchable(text: $search, prompt: "Paints, brands, sources…")
        .toolbar { toolbar }
        .sheet(isPresented: $showAdd) {
            AddEditPaintSheet(existing: nil, extraTypes: types) { name, type, brand, source, qty, notes, low in
                let ok = PaintStore.add(name: name, type: type, brand: brand, source: source,
                                        qty: qty, notes: notes, low: low, in: context)
                if ok { banner.show("Paint added") } else { banner.show("That name already exists") }
                return ok
            }
        }
        .sheet(isPresented: $showSettings) { SettingsScreen() }
        .sheet(isPresented: $showFilters) {
            PaintFilterSheet(cfg: cfg, types: types, brands: brands)
        }
        .confirmationDialog(
            "Delete \"\(paintToDelete?.name ?? "")\"?",
            isPresented: Binding(get: { paintToDelete != nil }, set: { if !$0 { paintToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let paint = paintToDelete {
                    if paint.id == selectedPaintId { selectedPaintId = nil }
                    PaintStore.delete(paint, in: context)
                    deleteWarningTrigger.toggle()
                }
                paintToDelete = nil
            }
            Button("Cancel", role: .cancel) { paintToDelete = nil }
        }
        .sensoryFeedback(.selection, trigger: filterTrigger)
        .sensoryFeedback(.warning, trigger: deleteWarningTrigger)
    }

    private var listBody: some View {
        let list = List {
            if filtersActive || !search.isEmpty {
                Section { summaryLine }
            }
            Section {
                ForEach(filtered) { paint in
                    Button {
                        selectedPaintId = paint.id
                        onSelectPaint(paint.id)
                    } label: {
                        paintRowLabel(paint)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(paint.id == selectedPaintId ? Color.accentColor.opacity(0.12) : nil)
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) { paintToDelete = paint }
                    }
                    .contextMenu { paintContextMenu(paint) }
                }
            }
        }
        return Group {
            if usesPadSidebarList {
                list.listStyle(.sidebar)
            } else {
                list.listStyle(.insetGrouped)
            }
        }
    }

    @ViewBuilder
    private func paintRowLabel(_ paint: Paint) -> some View {
        let linked = PaintStore.linkedUnitCount(source: paint.source, armies: armies)
        PaintRow(paint: paint, linkedCount: linked)
    }

    @ViewBuilder
    private func paintContextMenu(_ paint: Paint) -> some View {
        if !paint.source.isEmpty {
            Button("Filter collection by source", systemImage: "link") {
                router.showArmies(filteredBySource: paint.source)
                banner.show("Filtered by source")
                filterTrigger.toggle()
            }
        }
        Button("Delete", systemImage: "trash", role: .destructive) {
            paintToDelete = paint
        }
    }

    private var gridBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                summaryLine.padding(.horizontal)
                PaintGridView(paints: filtered, linkedCount: linkedUnitCount) { paint in
                    selectedPaintId = paint.id
                    onSelectPaint(paint.id)
                }
            }
            .padding(.vertical)
        }
    }

    private func linkedUnitCount(for paint: Paint) -> Int {
        PaintStore.linkedUnitCount(source: paint.source, armies: armies)
    }

    private var summaryLine: some View {
        let rows = filtered
        let total = rows.reduce(0) { $0 + $1.qty }
        let prefix = (filtersActive || !search.isEmpty) ? "Showing " : ""
        return Text("\(prefix)\(rows.count) paints · \(total) pots")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Add paint", systemImage: "plus") { showAdd = true }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(useGrid ? "List layout" : "Grid layout",
                   systemImage: useGrid ? "list.bullet" : "square.grid.2x2") {
                useGrid.toggle()
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Filters", systemImage: filtersActive
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
            Label("No paints yet", systemImage: "paintpalette")
        } description: {
            Text("Add a paint or import from Settings → Data.")
        } actions: {
            Button("Add paint") { showAdd = true }.buttonStyle(.borderedProminent)
        }
        .safeAreaPadding(.bottom, 72)
    }

    private var noMatches: some View {
        ContentUnavailableView {
            Label("No matching paints", systemImage: "paintpalette")
        } description: {
            Text("Nothing matches your search or filters.")
        } actions: {
            Button("Clear filters") {
                cfg.paintTypeFilter = "All"
                cfg.paintBrandFilter = "All"
                cfg.paintLowOnly = false
                search = ""
            }.buttonStyle(.borderedProminent)
        }
    }
}
