import SwiftUI
import SwiftData

@MainActor
struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(BannerCenter.self) private var banner
    @Query private var configs: [AppConfiguration]
    @Query private var armies: [Army]

    private var cfg: AppConfiguration { configs.first ?? Config.current(context) }

    var body: some View {
        @Bindable var cfg = cfg
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: Binding(
                        get: { cfg.theme }, set: { cfg.theme = $0; try? context.save() })) {
                        ForEach(ThemePreference.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Painting") {
                    NavigationLink("Pipeline stages") { PipelineEditor(cfg: cfg) }
                    NavigationLink("Faction crests & colours") {
                        FactionOverridesEditor(cfg: cfg, armies: armies)
                    }
                }

                SettingsDataSection()

                Section("About") {
                    LabeledContent("App", value: AppInfo.displayName)
                    LabeledContent("Version") {
                        Text(Bundle.main.appVersion)
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink("Privacy Policy") { PrivacyPolicyView() }
                    Text("For the Emperor · For the Great Horned Rat · Sigmar Watches")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

/// Global pipeline editor.
private struct PipelineEditor: View {
    @Environment(\.modelContext) private var context
    @Bindable var cfg: AppConfiguration
    @State private var stages: [PipelineStage] = []

    var body: some View {
        List {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, _ in
                HStack {
                    TextField("Stage name", text: $stages[index].key)
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: stages[index].hex) },
                        set: { stages[index].hex = $0.hexString }))
                    .labelsHidden()
                }
            }
            .onDelete { stages.remove(atOffsets: $0) }
            .onMove { stages.move(fromOffsets: $0, toOffset: $1) }
            Button("Add stage", systemImage: "plus") {
                stages.append(PipelineStage(key: "New", hex: "#888888"))
            }
            Button("Reset to default") { stages = DefaultPipeline.stages }
        }
        .navigationTitle("Pipeline")
        .toolbar { EditButton() }
        .onAppear { stages = Pipeline.resolve(cfg.globalPipeline) }
        .onDisappear {
            let cleaned = stages
                .filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { PipelineStage(key: $0.key, hex: safeColor($0.hex)) }
            cfg.globalPipeline = (cleaned.isEmpty || cleaned == DefaultPipeline.stages) ? nil : cleaned
            try? context.save()
        }
    }
}

private struct FactionOverridesEditor: View {
    @Environment(\.modelContext) private var context
    @Bindable var cfg: AppConfiguration
    let armies: [Army]

    struct Row: Identifiable { let id: String; let game: String; let faction: String }

    @State private var crest: [String: String] = [:]
    @State private var color: [String: Color] = [:]

    private var rows: [Row] {
        var seen = Set<String>()
        var out: [Row] = []
        for a in armies {
            let key = FactionResolver.compositeKey(game: a.game, faction: a.faction)
            if seen.insert(key).inserted { out.append(Row(id: key, game: a.game, faction: a.faction)) }
        }
        return out.sorted { $0.id < $1.id }
    }

    var body: some View {
        List(rows) { row in
            VStack(alignment: .leading, spacing: 6) {
                Text(row.id).font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("Crest", text: Binding(
                        get: { crest[row.id] ?? "" },
                        set: { crest[row.id] = String($0.prefix(8)) }))
                    ColorPicker("", selection: Binding(
                        get: { color[row.id] ?? .gray },
                        set: { color[row.id] = $0 }))
                    .labelsHidden()
                }
            }
        }
        .navigationTitle("Factions")
        .onAppear(perform: seed)
        .onDisappear(perform: save)
    }

    private func seed() {
        for row in rows {
            let r = FactionResolver.resolve(faction: row.faction, game: row.game, overrides: cfg.factionOverrides)
            crest[row.id] = r.crest
            color[row.id] = Color(hex: r.color)
        }
    }

    private func save() {
        cfg.factionOverrides = rows.map { row in
            FactionPresetOverride(key: row.id,
                                  crest: String((crest[row.id] ?? "").prefix(8)),
                                  hex: (color[row.id] ?? .gray).hexString)
        }
        try? context.save()
    }
}
