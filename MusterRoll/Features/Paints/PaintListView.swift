import SwiftUI
import SwiftData

@MainActor
struct PaintListView: View {
    @Environment(\.modelContext) private var context
    @Environment(BannerCenter.self) private var banner
    @Environment(AppRouter.self) private var router
    @Query(sort: \Paint.name) private var paints: [Paint]
    @Query private var armies: [Army]
    @Query private var configs: [AppConfiguration]

    @Binding var selectedPaintId: UUID?

    @State private var search = ""
    @State private var showAdd = false
    @State private var showFilters = false
    @AppStorage("paintUseGrid") private var useGrid = false
    @State private var filterTrigger = false

    private var cfg: AppConfiguration { configs.first ?? Config.current(context) }
    private var types: [String] { Array(Set(paints.map(\.type).filter { !$0.isEmpty })).sorted() }
    private var brands: [String] { Array(Set(paints.map(\.brand).filter { !$0.isEmpty })).sorted() }

    private var filtersActive: Bool {
        cfg.paintTypeFilter != "All" || cfg.paintBrandFilter != "All" || cfg.paintLowOnly
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
        .sheet(isPresented: $showFilters) {
            PaintFilterSheet(cfg: cfg, types: types, brands: brands)
        }
        .sensoryFeedback(.selection, trigger: filterTrigger)
    }

    private var listBody: some View {
        List(selection: $selectedPaintId) {
            if filtersActive || !search.isEmpty {
                Section { summaryLine }
            }
            Section {
                ForEach(filtered) { paint in
                    paintRow(paint)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func paintRow(_ paint: Paint) -> some View {
        let linked = PaintStore.linkedUnitCount(source: paint.source, armies: armies)
        PaintRow(paint: paint, linkedCount: linked)
            .tag(paint.id as UUID?)
            .swipeActions(edge: .trailing) {
                Button("Delete", role: .destructive) { deletePaint(paint) }
            }
            .contextMenu { paintContextMenu(paint) }
    }

    private func deletePaint(_ paint: Paint) {
        if paint.id == selectedPaintId { selectedPaintId = nil }
        PaintStore.delete(paint, in: context)
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
            deletePaint(paint)
        }
    }

    private var gridBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                summaryLine.padding(.horizontal)
                PaintGridView(paints: filtered) { paint in
                    selectedPaintId = paint.id
                }
            }
            .padding(.vertical)
        }
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
