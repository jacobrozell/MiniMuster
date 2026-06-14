import SwiftUI

/// Filters/search/sort controls for the Armies tab. Mirrors `renderArmyFilters`.
/// Prefs bind directly to `AppConfiguration` (SwiftData autosaves). Quick-view is a
/// segmented control; the rest are menus to stay compact on iPhone.
struct ArmyFilterBar: View {
    @Bindable var cfg: AppConfiguration
    @Binding var search: String

    let games: [String]
    let factions: [String]
    let sources: [String]
    let states: [String]
    let tags: [String]
    let overrides: [FactionPresetOverride]

    var body: some View {
        VStack(spacing: 8) {
            TextField("Search units, factions, sources…", text: $search)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            Picker("View", selection: $cfg.quickViewRaw) {
                Text("All").tag("all")
                Text("Backlog").tag("backlog")
                Text("WIP").tag("wip")
                Text("Table-ready").tag("ready")
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterMenu("Game", selection: $cfg.gameFilter, options: ["All"] + games)
                    filterMenu("Faction", selection: $cfg.factionFilter, options: ["All"] + factions, dots: true)
                    filterMenu("State", selection: $cfg.stateFilter, options: states)
                    filterMenu("Source", selection: $cfg.sourceFilter, options: ["All"] + sources)
                    if !tags.isEmpty {
                        filterMenu("Tag", selection: $cfg.tagFilter, options: ["All"] + tags, hash: true)
                    }
                    Toggle("Spearhead", isOn: $cfg.spearheadOnly)
                        .toggleStyle(.button)
                        .font(.caption)

                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
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
                    .font(.caption)
                }
            }
        }
    }

    private func filterMenu(_ title: String, selection: Binding<String>,
                            options: [String], dots: Bool = false, hash: Bool = false) -> some View {
        Menu {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { opt in
                    Text(hash && opt != "All" ? "#\(opt)" : opt).tag(opt)
                }
            }
        } label: {
            let value = selection.wrappedValue
            HStack(spacing: 4) {
                if dots, value != "All" {
                    Circle().fill(Color(hex: factionColor(value))).frame(width: 8, height: 8)
                }
                Text(value == "All" ? title : (hash ? "#\(value)" : value))
            }
            .font(.caption)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(value == "All" ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color.accentColor.opacity(0.2)),
                        in: Capsule())
        }
    }

    private func factionColor(_ faction: String) -> String {
        FactionResolver.resolve(faction: faction, game: cfg.gameFilter == "All" ? "" : cfg.gameFilter,
                                overrides: overrides).color
    }
}
