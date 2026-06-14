import SwiftUI
import SwiftData

/// Paint Rack tab (M4): card grid, CRUD, type/brand/stock filters, search, scoped stats,
/// and source ↔ Armies linking. Mirrors `js/render/paints.js`.
@MainActor
struct PaintRackScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Environment(AppRouter.self) private var router
    @Query(sort: \Paint.name) private var paints: [Paint]
    @Query private var armies: [Army]
    @Query private var configs: [AppConfiguration]

    @State private var search = ""
    @State private var editing: Paint?
    @State private var showAdd = false

    private var cfg: AppConfiguration { configs.first ?? Config.current(context) }
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    private var types: [String] { Array(Set(paints.map(\.type).filter { !$0.isEmpty })).sorted() }
    private var brands: [String] { Array(Set(paints.map(\.brand).filter { !$0.isEmpty })).sorted() }

    private var filtersActive: Bool {
        cfg.paintTypeFilter != "All" || cfg.paintBrandFilter != "All" || cfg.paintLowOnly || !search.isEmpty
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
            else { content }
        }
        .navigationTitle("Paint Rack")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Add paint", systemImage: "plus") { showAdd = true }
            }
        }
        .dataPortToolbar(.paints)
        .sheet(isPresented: $showAdd) {
            AddEditPaintSheet(existing: nil, extraTypes: types) { name, type, brand, source, qty, notes, low in
                let ok = PaintStore.add(name: name, type: type, brand: brand, source: source,
                                        qty: qty, notes: notes, low: low, in: context)
                toast.show(ok ? "Paint added" : "That name already exists")
                return ok
            }
        }
        .sheet(item: $editing) { paint in
            AddEditPaintSheet(existing: paint, extraTypes: types) { name, type, brand, source, qty, notes, low in
                PaintStore.update(paint, name: name, type: type, brand: brand, source: source,
                                  qty: qty, notes: notes, low: low, in: context)
            }
        }
    }

    @ViewBuilder private var content: some View {
        @Bindable var cfg = cfg
        let rows = filtered
        ScrollView {
            VStack(spacing: 12) {
                statsHeader(rows)
                filterBar(cfg: cfg)

                if rows.isEmpty {
                    ContentUnavailableView {
                        Label("No matching paints", systemImage: "paintpalette")
                    } description: {
                        Text("Nothing matches your current search or filters.")
                    } actions: {
                        Button("Clear filters") { clearFilters() }.buttonStyle(.borderedProminent)
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(rows) { paint in
                            PaintCard(paint: paint,
                                      linked: PaintStore.linkedUnitCount(source: paint.source, armies: armies),
                                      onEdit: { editing = paint },
                                      onDelete: {
                                          PaintStore.delete(paint, in: context)
                                          toast.show("Paint removed")
                                      },
                                      onSource: { applySource(paint.source) })
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func statsHeader(_ rows: [Paint]) -> some View {
        let scoped = filtersActive
        let stat = scoped ? rows : paints
        let total = stat.reduce(0) { $0 + $1.qty }
        let typeCount = Set(stat.map(\.type).filter { !$0.isEmpty }).count
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
            StatTile(value: stat.count, label: scoped ? "Distinct (filtered)" : "Distinct Paints")
            StatTile(value: total, label: scoped ? "Pots (filtered)" : "Total Pots", accent: true)
            StatTile(value: typeCount, label: "Types")
        }
    }

    private func filterBar(cfg: AppConfiguration) -> some View {
        @Bindable var cfg = cfg
        return VStack(spacing: 8) {
            TextField("Search paints…", text: $search)
                .textFieldStyle(.roundedBorder)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    pill("Type", selection: $cfg.paintTypeFilter, options: ["All"] + types)
                    pill("Brand", selection: $cfg.paintBrandFilter, options: ["All"] + brands)
                    Toggle("Running low", isOn: $cfg.paintLowOnly)
                        .toggleStyle(.button).font(.caption)
                }
            }
        }
    }

    private func pill(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        Menu {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
        } label: {
            Text(selection.wrappedValue == "All" ? title : selection.wrappedValue)
                .font(.caption)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
        }
    }

    private func applySource(_ source: String) {
        guard !source.isEmpty else { return }
        router.showArmies(filteredBySource: source)
        toast.show("Filtered armies by source")
    }

    private func clearFilters() {
        cfg.paintTypeFilter = "All"; cfg.paintBrandFilter = "All"; cfg.paintLowOnly = false
        search = ""
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No paints yet", systemImage: "paintpalette")
        } description: {
            Text("Import warhammer_paint_inventory.csv via the Data menu, add a paint, or load the sample collection.")
        } actions: {
            Button("Load sample data") { toast.show(DataActions.loadSample(ctx: context)) }
                .buttonStyle(.borderedProminent)
            Button("Add paint") { showAdd = true }
        }
    }
}

/// One paint card. Mirrors the web `.paint` card.
struct PaintCard: View {
    let paint: Paint
    let linked: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSource: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: paint.swatchHex))
                .frame(height: 36)
            HStack {
                Text(paint.name).font(.subheadline.bold())
                if paint.low {
                    Text("LOW").font(.caption2.bold())
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(.orange.opacity(0.25), in: Capsule())
                }
                Spacer()
                if paint.qty > 1 { Text("×\(paint.qty)").font(.caption2).foregroundStyle(.secondary) }
            }
            let meta = [paint.type, paint.brand].filter { !$0.isEmpty }.joined(separator: " · ")
            if !meta.isEmpty { Text(meta).font(.caption).foregroundStyle(.secondary) }
            if !paint.source.isEmpty {
                Button {
                    onSource()
                } label: {
                    Text("\(paint.source)\(linked > 0 ? " (\(linked))" : "")")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: "#c9a44c"))
                }
                .buttonStyle(.borderless)
            }
            if !paint.notes.isEmpty { Text(paint.notes).font(.caption2).foregroundStyle(.secondary) }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Edit", systemImage: "pencil", action: onEdit)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle").padding(6)
            }
        }
    }
}
