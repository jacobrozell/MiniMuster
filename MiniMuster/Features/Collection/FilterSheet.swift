import SwiftUI

/// Collection filter and sort controls (sheet).
struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var cfg: AppConfiguration

    let games: [String]
    let factions: [String]
    let sources: [String]
    let states: [String]
    let tags: [String]
    let overrides: [FactionPresetOverride]

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick view") {
                    Picker("View", selection: $cfg.quickViewRaw) {
                        Text("All").tag("all")
                        Text("Backlog").tag("backlog")
                        Text("WIP").tag("wip")
                        Text("Table-ready").tag("ready")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Narrow by") {
                    Picker("Game", selection: $cfg.gameFilter) {
                        ForEach(["All"] + games, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Faction", selection: $cfg.factionFilter) {
                        ForEach(["All"] + factions, id: \.self) { f in
                            HStack {
                                if f != "All" {
                                    Circle().fill(Color(hex: factionColor(f))).frame(width: 8, height: 8)
                                }
                                Text(f)
                            }.tag(f)
                        }
                    }
                    Picker("State", selection: $cfg.stateFilter) {
                        ForEach(states, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Source", selection: $cfg.sourceFilter) {
                        ForEach(["All"] + sources, id: \.self) { Text($0).tag($0) }
                    }
                    if !tags.isEmpty {
                        Picker("Tag", selection: $cfg.tagFilter) {
                            ForEach(["All"] + tags, id: \.self) { t in
                                Text(t == "All" ? "All" : "#\(t)").tag(t)
                            }
                        }
                    }
                    Toggle("Spearhead only", isOn: $cfg.spearheadOnly)
                }

                Section("Sort") {
                    Picker("Armies", selection: $cfg.armySortRaw) {
                        Text("Import order").tag("import")
                        Text("Name").tag("name")
                        Text("Least complete").tag("progress")
                    }
                    Picker("Units", selection: $cfg.unitSortRaw) {
                        Text("Name").tag("name")
                        Text("State").tag("state")
                    }
                }

                Section {
                    Button("Clear all filters", role: .destructive) {
                        ArmyFilter.clearFilters(cfg)
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { try? context.save(); dismiss() }
                }
            }
        }
    }

    private func factionColor(_ faction: String) -> String {
        FactionResolver.resolve(faction: faction,
                                game: cfg.gameFilter == "All" ? "" : cfg.gameFilter,
                                overrides: overrides).color
    }
}
