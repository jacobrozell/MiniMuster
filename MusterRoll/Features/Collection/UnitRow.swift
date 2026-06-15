import SwiftUI
import SwiftData

/// Read-only unit summary for list rows (army detail).
struct UnitRow: View {
    let unit: Unit
    let pipeline: [PipelineStage]
    let showSpearhead: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(unit.name)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                StateChip(state: unit.state, pipeline: pipeline)
                    .fixedSize()
                    .layoutPriority(-1)
            }
            HStack(spacing: 6) {
                if !unit.source.isEmpty {
                    Text(unit.source)
                }
                Text("·")
                Text(modelLabel)
                if showSpearhead, unit.spearhead == true {
                    Text("·")
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Spearhead")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            if unit.hasSquadMembers {
                Text(Members.stateSummary(of: unit))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Opens unit details")
    }

    private var modelLabel: String {
        let n = unit.modelCount
        return n == 1 ? "1 model" : "\(n) models"
    }

    private var accessibilityText: String {
        var parts = [unit.name, unit.state, modelLabel]
        if !unit.source.isEmpty { parts.append(unit.source) }
        if unit.spearhead == true { parts.append("spearhead") }
        return parts.joined(separator: ", ")
    }
}
