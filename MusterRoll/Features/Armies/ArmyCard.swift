import SwiftUI
import SwiftData

/// One army card: header (crest, name, meta, %, actions), meter, unit rows, footer actions.
/// Mirrors `armyBlock` (`js/render/armies.js`).
struct ArmyCard: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var army: Army
    let overrides: [FactionPresetOverride]
    let globalPipeline: [PipelineStage]?
    let allArmyNames: [String]
    /// Filtered/sorted units to display (from `ArmyFilter`). Card stats reflect this set,
    /// matching the web (`armyBlock` receives the visible units).
    let visibleUnits: [Unit]

    @State private var showAddUnit = false
    @State private var showRename = false
    @State private var confirmDelete = false

    private var pipeline: [PipelineStage] { Pipeline.forArmy(army, global: globalPipeline) }
    private var usesSpearhead: Bool { visibleUnits.contains { $0.spearhead != nil } }
    private var percent: Int { Int((Pipeline.progress(of: visibleUnits, pipeline) * 100).rounded()) }

    var body: some View {
        let pres = army.presentation(overrides: overrides)
        VStack(alignment: .leading, spacing: 10) {
            header(pres)
            ProgressMeter(segments: Pipeline.segments(of: visibleUnits, pipeline), height: 8)

            if !army.isCollapsed {
                ForEach(visibleUnits) { unit in
                    UnitRow(unit: unit, pipeline: pipeline, showSpearhead: usesSpearhead,
                            otherArmyNames: allArmyNames.filter { $0 != army.name })
                    Divider()
                }
                footer
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: pres.colorHex))
                .frame(width: 4)
                .padding(.vertical, 8)
        }
        .sheet(isPresented: $showAddUnit) {
            AddUnitSheet(pipeline: pipeline) { name, qty, source, state in
                ArmyStore.addUnit(to: army, name: name, qty: qty, source: source, state: state, in: ctx)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showRename) {
            RenameArmySheet(current: army.name) { ArmyStore.rename(army, to: $0, in: ctx) }
                .presentationDetents([.height(200)])
        }
        .confirmationDialog("Delete entire army \"\(army.name)\" and all its units?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { ArmyStore.delete(army, in: ctx) }
        }
    }

    private func header(_ pres: (crest: String, colorHex: String)) -> some View {
        HStack(spacing: 12) {
            Button {
                ArmyStore.toggleCollapse(army, in: ctx)
            } label: {
                HStack(spacing: 12) {
                    CrestBadge(text: pres.crest, colorHex: pres.colorHex)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(army.name).font(.headline)
                        Text("\(army.game) · \(army.faction) · \(visibleUnits.count) entries\(army.customPipeline?.isEmpty == false ? " · custom pipeline" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(percent)%").font(.system(.body, design: .serif)).monospacedDigit()
                        Text("complete").font(.caption2).foregroundStyle(.secondary)
                    }
                    Image(systemName: army.isCollapsed ? "chevron.down" : "chevron.up")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Menu {
                Button("Reset crest & colour", systemImage: "circle.lefthalf.filled") {
                    ArmyStore.resetTheme(army, in: ctx)
                }
                Button("Rename", systemImage: "pencil") { showRename = true }
                Button("Delete army", systemImage: "trash", role: .destructive) { confirmDelete = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Army actions")
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Add unit", systemImage: "plus") { showAddUnit = true }
            Button("Advance all", systemImage: "arrow.right.to.line") {
                _ = ArmyStore.advanceAll(in: army, global: globalPipeline, in: ctx)
            }
            Button("Merge dups", systemImage: "square.on.square") {
                _ = ArmyStore.mergeDuplicates(in: army, ctx: ctx)
            }
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .padding(.top, 4)
    }
}
