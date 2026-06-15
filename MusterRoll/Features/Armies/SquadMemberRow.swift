import SwiftUI
import SwiftData

/// One per-model row beneath an expanded squad. Mirrors `memberRow` (`js/render/armies.js`).
struct SquadMemberRow: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var unit: Unit
    let member: SquadMember
    let pipeline: [PipelineStage]

    @State private var notes: String = ""

    private var effectiveState: String { Members.effectiveState(of: unit, at: member.index) }
    private var canAdvance: Bool { Pipeline.next(after: effectiveState, in: pipeline) != nil }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("#\(member.index + 1)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)

                StateMenu(state: effectiveState, pipeline: pipeline) {
                    SquadStore.setMemberState(unit, index: member.index, state: $0, in: ctx)
                }

                if canAdvance {
                    Button {
                        SquadStore.advanceMember(unit, index: member.index, pipeline: pipeline, in: ctx)
                    } label: { Image(systemName: "arrow.right.circle") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Advance model \(member.index + 1)")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Model \(member.index + 1) of \(unit.modelCount), state \(effectiveState)")

            TextField("model note…", text: $notes)
                .font(.caption2)
                .accessibilityLabel("Notes for model \(member.index + 1)")
                .onChange(of: notes) { SquadStore.setMemberNotes(unit, index: member.index, notes: notes, in: ctx) }
        }
        .onAppear { notes = member.notes ?? "" }
    }
}
