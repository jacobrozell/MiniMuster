import SwiftUI
import SwiftData

/// One inline-editable unit row. Mirrors `unitRow` (`js/render/armies.js`). Name/source/qty/
/// notes bind directly to the model (SwiftData autosaves); state changes route through
/// `ArmyStore` so undo (M6) can hook in. Per-model squad expansion is M4 — the summary is
/// shown read-only here.
struct UnitRow: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var unit: Unit
    let pipeline: [PipelineStage]
    let showSpearhead: Bool
    let otherArmyNames: [String]

    @State private var showMove = false
    @State private var confirmDelete = false
    @State private var expanded = false

    private var canAdvance: Bool { Pipeline.next(after: unit.state, in: pipeline) != nil || unit.hasSquadMembers && Pipeline.canAdvance(unit, pipeline) }
    private var trackable: Bool { unit.modelCount >= 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if trackable { squadToggle }
                TextField("Unit name", text: $unit.name)
                    .font(.body.weight(.medium))
                    .textInputAutocapitalization(.words)
                Spacer(minLength: 4)
                StateMenu(state: unit.state, pipeline: pipeline) {
                    ArmyStore.setState(unit, $0, in: ctx)
                }
                if canAdvance {
                    Button {
                        ArmyStore.advance(unit, pipeline: pipeline, in: ctx)
                    } label: { Image(systemName: "arrow.right.circle.fill") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Advance one stage")
                }
            }

            HStack(spacing: 10) {
                TextField("Source", text: $unit.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Stepper("Qty \(unit.qty)", value: $unit.qty, in: 1...9999)
                    .labelsHidden()
                    .fixedSize()
                    .onChange(of: unit.qty) { ArmyStore.resizeMembers(unit, in: ctx); try? ctx.save() }
                Text("Qty \(unit.qty)").font(.caption2).foregroundStyle(.secondary)
                if showSpearhead {
                    Button {
                        ArmyStore.setSpearhead(unit, !(unit.spearhead ?? false), in: ctx)
                    } label: {
                        Image(systemName: unit.spearhead == true ? "star.fill" : "star")
                            .foregroundStyle(unit.spearhead == true ? Color(hex: "#c9a44c") : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Spearhead")
                    .accessibilityValue(unit.spearhead == true ? "on" : "off")
                }
                Menu {
                    Button("Duplicate", systemImage: "plus.square.on.square") {
                        ArmyStore.duplicate(unit, in: ctx)
                    }
                    Button("Move to…", systemImage: "arrow.right.arrow.left") { showMove = true }
                        .disabled(otherArmyNames.isEmpty)
                    Button("Remove", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Unit actions")
            }

            if unit.hasSquadMembers {
                HStack {
                    Text(Members.stateSummary(of: unit))
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button("Track as single", systemImage: "person.fill") {
                        expanded = false
                        SquadStore.disable(unit, in: ctx)
                    }
                    .labelStyle(.iconOnly).font(.caption2).buttonStyle(.borderless)
                    .accessibilityLabel("Track as single unit")
                }
            }

            TextField("Notes", text: $unit.notes, axis: .vertical)
                .font(.caption)
                .lineLimit(1...3)

            if unit.hasSquadMembers && expanded {
                VStack(spacing: 4) {
                    ForEach(unit.orderedMembers) { member in
                        SquadMemberRow(unit: unit, member: member, pipeline: pipeline)
                    }
                }
                .padding(.leading, 12)
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog("Remove \"\(unit.name)\"?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { ArmyStore.delete(unit, in: ctx) }
        }
        .sheet(isPresented: $showMove) {
            MoveUnitSheet(unitName: unit.name, destinations: otherArmyNames) { dest in
                if let target = army(named: dest) { _ = ArmyStore.move(unit, to: target, in: ctx) }
            }
            .presentationDetents([.medium])
        }
    }

    /// Squad expand/enable toggle. Cycles off → on+expanded → collapsed → expanded.
    private var squadToggle: some View {
        Button {
            if !unit.hasSquadMembers {
                SquadStore.enable(unit, in: ctx)
                expanded = true
            } else {
                expanded.toggle()
            }
        } label: {
            Image(systemName: unit.hasSquadMembers
                  ? (expanded ? "chevron.down" : "chevron.right")
                  : "person.3")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Per-model tracking")
    }

    private func army(named name: String) -> Army? {
        let d = FetchDescriptor<Army>(predicate: #Predicate { $0.name == name })
        return try? ctx.fetch(d).first
    }
}
