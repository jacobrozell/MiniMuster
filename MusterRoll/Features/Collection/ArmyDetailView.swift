import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// One army's units: native list with swipe actions and drill-down to unit detail.
@MainActor
struct ArmyDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(BannerCenter.self) private var banner
    @Query private var configs: [AppConfiguration]
    @Query private var allArmies: [Army]

    let armyId: UUID
    @Binding var selectedArmyId: UUID?
    @Binding var selectedUnitId: UUID?
    var onSelectUnit: (UUID) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    @State private var showAddUnit = false
    @State private var showRename = false
    @State private var showPipeline = false
    @State private var confirmDeleteArmy = false
    @State private var unitToDelete: Unit?
    @State private var advanceTrigger = false
    @State private var isEditing = false
    @State private var batchSelection = Set<UUID>()
    @State private var confirmBatchDelete = false
    @State private var unitToMove: Unit?
    @State private var showMoveUnit = false
    @State private var deleteWarningTrigger = false
    @State private var duplicateTrigger = false

    private var cfg: AppConfiguration { configs.first ?? Config.current(context) }
    private var overrides: [FactionPresetOverride] { cfg.factionOverrides }
    private var globalPipeline: [PipelineStage]? { cfg.globalPipeline }

    private var army: Army? { allArmies.first { $0.id == armyId } }

    private var visibleUnits: [Unit] {
        guard let army else { return [] }
        let vis = ArmyFilter.build(armies: [army], cfg: cfg, search: router.collectionSearch,
                                   global: globalPipeline)
        return vis.first?.units ?? army.orderedUnits
    }

    private var pipeline: [PipelineStage] {
        guard let army else { return Pipeline.resolve(globalPipeline) }
        return Pipeline.forArmy(army, global: globalPipeline)
    }

    private var usesSpearhead: Bool { visibleUnits.contains { $0.spearhead != nil } }
    private var percent: Int { Int((Pipeline.progress(of: visibleUnits, pipeline) * 100).rounded()) }

    private var selectedUnits: [Unit] {
        visibleUnits.filter { batchSelection.contains($0.id) }
    }

    private var otherArmyNames: [String] {
        guard let army else { return [] }
        return allArmies.map(\.name).filter { $0 != army.name }
    }

    private var armyTitleDisplayMode: NavigationBarItem.TitleDisplayMode {
#if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad ? .inline : .large
#else
        .large
#endif
    }

    var body: some View {
        Group {
            if let army { unitList(army: army) }
            else { ContentUnavailableView("Army not found", systemImage: "shield") }
        }
        .navigationTitle(army?.name ?? "Army")
        .navigationBarTitleDisplayMode(armyTitleDisplayMode)
        .toolbar { armyToolbar }
        .safeAreaInset(edge: .bottom) { batchActionBar }
        .sheet(isPresented: $showAddUnit) {
            if let army {
                AddUnitSheet(pipeline: pipeline) { name, qty, source, state in
                    ArmyStore.addUnit(to: army, name: name, qty: qty, source: source, state: state, in: context)
                }
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showRename) {
            if let army {
                RenameArmySheet(current: army.name) { ArmyStore.rename(army, to: $0, in: context) }
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showPipeline) {
            if let army {
                ArmyPipelineEditorSheet(army: army, globalPipeline: globalPipeline)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showMoveUnit) {
            if let unit = unitToMove {
                MoveUnitSheet(unitName: unit.name, destinations: otherArmyNames) { dest in
                    if let target = allArmies.first(where: { $0.name == dest }) {
                        _ = ArmyStore.move(unit, to: target, in: context)
                        if unit.id == selectedUnitId { selectedUnitId = nil }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .confirmationDialog("Delete entire army \"\(army?.name ?? "")\" and all its units?",
                            isPresented: $confirmDeleteArmy, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let army {
                    if army.id == selectedArmyId { selectedArmyId = nil }
                    ArmyStore.delete(army, in: context)
                    dismiss()
                }
            }
        }
        .confirmationDialog("Remove \"\(unitToDelete?.name ?? "")\"?",
                            isPresented: Binding(get: { unitToDelete != nil }, set: { if !$0 { unitToDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let unit = unitToDelete {
                    if unit.id == selectedUnitId { selectedUnitId = nil }
                    ArmyStore.delete(unit, in: context)
                    deleteWarningTrigger.toggle()
                }
                unitToDelete = nil
            }
            Button("Cancel", role: .cancel) { unitToDelete = nil }
        }
        .confirmationDialog("Remove \(batchSelection.count) selected unit\(batchSelection.count == 1 ? "" : "s")?",
                            isPresented: $confirmBatchDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { deleteBatchSelection() }
            Button("Cancel", role: .cancel) {}
        }
        .sensoryFeedback(.success, trigger: advanceTrigger)
        .sensoryFeedback(.warning, trigger: deleteWarningTrigger)
        .sensoryFeedback(.impact(weight: .light), trigger: duplicateTrigger)
        .onChange(of: isEditing) { _, editing in
            if editing {
                selectedUnitId = nil
            } else {
                batchSelection.removeAll()
            }
        }
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
    }

    @ViewBuilder
    private func unitList(army: Army) -> some View {
        let pres = army.presentation(overrides: overrides)
        if isEditing {
            editModeList(army: army, pres: pres)
        } else {
            browseModeList(army: army, pres: pres)
        }
    }

    @ViewBuilder
    private func browseModeList(army: Army, pres: (crest: String, colorHex: String)) -> some View {
        List {
            armyHeaderSection(army: army, pres: pres)
            unitsSection(army: army)
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func editModeList(army: Army, pres: (crest: String, colorHex: String)) -> some View {
        List(selection: $batchSelection) {
            armyHeaderSection(army: army, pres: pres)
            Section("Units") {
                if visibleUnits.isEmpty {
                    ContentUnavailableView {
                        Label("No units", systemImage: "figure.stand")
                    } description: {
                        Text("Add a unit or adjust filters.")
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(visibleUnits) { unit in
                        unitRow(unit)
                            .tag(unit.id)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func armyHeaderSection(army: Army, pres: (crest: String, colorHex: String)) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(army.game) · \(army.faction)\(army.customPipeline?.isEmpty == false ? " · custom pipeline" : "")")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    CrestBadge(text: pres.crest, colorHex: pres.colorHex)
                    Spacer()
                    Text("\(percent)% complete").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
                ProgressMeter(segments: Pipeline.segments(of: visibleUnits, pipeline), height: 8)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func unitsSection(army: Army) -> some View {
        Section("Units") {
            if visibleUnits.isEmpty {
                ContentUnavailableView {
                    Label("No units", systemImage: "figure.stand")
                } description: {
                    Text("Add a unit or adjust filters.")
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(visibleUnits) { unit in
                    Button {
                        selectedUnitId = unit.id
                        onSelectUnit(unit.id)
                    } label: {
                        unitRow(unit)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("unit-\(unit.name)")
                    .listRowBackground(unit.id == selectedUnitId ? Color.accentColor.opacity(0.12) : nil)
                }
            }
        }
    }

    @ViewBuilder
    private func unitRow(_ unit: Unit) -> some View {
        UnitRow(unit: unit, pipeline: pipeline, showSpearhead: usesSpearhead)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if !isEditing, canAdvance(unit) {
                    Button("Advance") {
                        ArmyStore.advance(unit, pipeline: pipeline, in: context)
                        advanceTrigger.toggle()
                    }
                    .tint(.accentColor)
                    .accessibilityLabel("Advance painting state")
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !isEditing {
                    Button("Duplicate") { duplicateUnit(unit) }
                    .accessibilityLabel("Duplicate unit")
                    Button("Delete", role: .destructive) { unitToDelete = unit }
                        .accessibilityLabel("Delete unit")
                }
            }
            .contextMenu {
                if !isEditing {
                    if canAdvance(unit) {
                        Button("Advance", systemImage: "arrow.right.circle") {
                            ArmyStore.advance(unit, pipeline: pipeline, in: context)
                            advanceTrigger.toggle()
                        }
                    }
                    Button("Duplicate", systemImage: "plus.square.on.square") { duplicateUnit(unit) }
                    if !otherArmyNames.isEmpty {
                        Button("Move to…", systemImage: "arrow.right.arrow.left") {
                            unitToMove = unit
                            showMoveUnit = true
                        }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        unitToDelete = unit
                    }
                }
            }
    }

    @ViewBuilder
    private var batchActionBar: some View {
        if isEditing, !batchSelection.isEmpty {
            HStack(spacing: 12) {
                Text("\(batchSelection.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Advance") {
                    let n = ArmyStore.advance(selectedUnits, pipeline: pipeline, in: context)
                    banner.show(n > 0 ? "Advanced \(n) unit\(n == 1 ? "" : "s")" : "Nothing to advance")
                    if n > 0 { advanceTrigger.toggle() }
                    batchSelection.removeAll()
                }
                .buttonStyle(.borderedProminent)
                Button("Delete", role: .destructive) { confirmBatchDelete = true }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    @ToolbarContentBuilder private var armyToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isEditing {
                Button("Done") { isEditing = false }
            } else {
                Button("Select") { isEditing = true }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Add unit", systemImage: "plus") { showAddUnit = true }
                .disabled(isEditing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Advance all", systemImage: "arrow.right.to.line") {
                    if let army {
                        let n = ArmyStore.advanceAll(in: army, global: globalPipeline, in: context)
                        banner.show(n > 0 ? "Advanced \(n) unit\(n == 1 ? "" : "s")" : "Nothing to advance")
                        if n > 0 { advanceTrigger.toggle() }
                    }
                }
                Button("Merge duplicates", systemImage: "square.on.square") {
                    if let army {
                        let n = ArmyStore.mergeDuplicates(in: army, ctx: context)
                        if n > 0 { banner.show("Merged \(n) duplicate\(n == 1 ? "" : "s")") }
                    }
                }
                Divider()
                Button("Pipeline stages", systemImage: "list.bullet") { showPipeline = true }
                Button("Reset crest & colour", systemImage: "circle.lefthalf.filled") {
                    if let army { ArmyStore.resetTheme(army, in: context) }
                }
                Button("Rename", systemImage: "pencil") { showRename = true }
                Button("Delete army", systemImage: "trash", role: .destructive) { confirmDeleteArmy = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Army actions")
            .disabled(isEditing)
        }
    }

    private func deleteBatchSelection() {
        let ids = batchSelection
        for unit in visibleUnits where ids.contains(unit.id) {
            if unit.id == selectedUnitId { selectedUnitId = nil }
            ArmyStore.delete(unit, in: context)
        }
        deleteWarningTrigger.toggle()
        batchSelection.removeAll()
        isEditing = false
    }

    private func canAdvance(_ unit: Unit) -> Bool { Pipeline.canAdvance(unit, pipeline) }

    private func duplicateUnit(_ unit: Unit) {
        guard let copy = ArmyStore.duplicate(unit, in: context) else { return }
        banner.show("Duplicated \(unit.name)")
        duplicateTrigger.toggle()
        selectedUnitId = copy.id
        onSelectUnit(copy.id)
    }
}
