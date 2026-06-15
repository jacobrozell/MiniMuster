import SwiftUI
import SwiftData

/// Edit all fields for a single unit.
@MainActor
struct UnitDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(BannerCenter.self) private var banner
    @Query private var allArmies: [Army]

    let unitId: UUID

    @State private var showMove = false
    @State private var confirmDelete = false
    @State private var advanceTrigger = false
    @State private var deleteWarningTrigger = false
    @State private var duplicateTrigger = false

    private var unit: Unit? {
        allArmies.flatMap(\.units).first { $0.id == unitId }
    }

    private var army: Army? { unit?.army }

    private var globalPipeline: [PipelineStage]? {
        (try? context.fetch(FetchDescriptor<AppConfiguration>()))?.first?.globalPipeline
    }

    private var pipeline: [PipelineStage] {
        guard let army else { return Pipeline.resolve(globalPipeline) }
        return Pipeline.forArmy(army, global: globalPipeline)
    }

    private var usesSpearhead: Bool {
        guard let army else { return false }
        return army.units.contains { $0.spearhead != nil }
    }

    private var otherArmyNames: [String] {
        guard let army else { return [] }
        return allArmies.map(\.name).filter { $0 != army.name }
    }

    private var canAdvance: Bool {
        guard let unit else { return false }
        return Pipeline.canAdvance(unit, pipeline)
    }

    private var trackable: Bool { (unit?.modelCount ?? 0) >= 2 }

    var body: some View {
        Group {
            if let unit {
                unitForm(unit)
            } else {
                ContentUnavailableView("Unit not found", systemImage: "figure.stand")
            }
        }
        .navigationTitle(unit?.name.isEmpty == false ? unit!.name : "Unit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { unitToolbar }
        .confirmationDialog("Remove \"\(unit?.name ?? "")\"?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let unit {
                    ArmyStore.delete(unit, in: context)
                    deleteWarningTrigger.toggle()
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showMove) {
            if let unit {
                MoveUnitSheet(unitName: unit.name, destinations: otherArmyNames) { dest in
                    if let target = allArmies.first(where: { $0.name == dest }) {
                        _ = ArmyStore.move(unit, to: target, in: context)
                        dismiss()
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .sensoryFeedback(.success, trigger: advanceTrigger)
        .sensoryFeedback(.warning, trigger: deleteWarningTrigger)
        .sensoryFeedback(.impact(weight: .light), trigger: duplicateTrigger)
    }

    @ViewBuilder
    private func unitForm(_ unit: Unit) -> some View {
        @Bindable var unit = unit
        Form {
            Section("Unit") {
                TextField("Name", text: $unit.name)
                    .textInputAutocapitalization(.words)
                Stepper(value: Binding(
                    get: { unit.qty },
                    set: { ArmyStore.setQty(unit, $0, in: context) }
                ), in: 1...9999) {
                    Text("Quantity: \(unit.qty)")
                }
                if unit.hasSquadMembers {
                    Text("Squad tracks \(unit.modelCount) models.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField("Source", text: $unit.source)
                if usesSpearhead {
                    Toggle("Spearhead", isOn: Binding(
                        get: { unit.spearhead == true },
                        set: { ArmyStore.setSpearhead(unit, $0, in: context) }
                    ))
                }
            }

            Section("Painting") {
                Picker("State", selection: Binding(
                    get: { unit.state },
                    set: { ArmyStore.setState(unit, $0, in: context) }
                )) {
                    ForEach(pipeline) { stage in
                        Text(stage.key).tag(stage.key)
                    }
                }
                .accessibilityLabel("Painting state")
                .accessibilityValue(unit.state)
                if canAdvance {
                    Button("Advance one stage", systemImage: "arrow.right.circle.fill") {
                        ArmyStore.advance(unit, pipeline: pipeline, in: context)
                        advanceTrigger.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                }
                TextField("Notes", text: $unit.notes, axis: .vertical)
                    .lineLimit(3...8)
                Text("Add #tags in notes to filter later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            UnitPhotoSection(unit: unit, pipeline: pipeline)

            UnitTimelineSection(unit: unit, pipeline: pipeline)

            if trackable {
                Section("Squad") {
                    Toggle("Track per model", isOn: Binding(
                        get: { unit.hasSquadMembers },
                        set: { enabled in
                            if enabled { SquadStore.enable(unit, in: context) }
                            else { SquadStore.disable(unit, in: context) }
                        }
                    ))
                    if unit.hasSquadMembers {
                        Text(Members.stateSummary(of: unit))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(unit.orderedMembers) { member in
                            SquadMemberRow(unit: unit, member: member, pipeline: pipeline)
                        }
                    }
                }
            }

            Section {
                Button("Delete unit", role: .destructive) { confirmDelete = true }
            }
        }
    }

    @ToolbarContentBuilder private var unitToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Duplicate", systemImage: "plus.square.on.square") {
                    if let unit {
                        if ArmyStore.duplicate(unit, in: context) != nil {
                            banner.show("Duplicated \(unit.name)")
                            duplicateTrigger.toggle()
                        }
                    }
                }
                Button("Move to…", systemImage: "arrow.right.arrow.left") { showMove = true }
                    .disabled(otherArmyNames.isEmpty)
                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Unit actions")
        }
    }
}
