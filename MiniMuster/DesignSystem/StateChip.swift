import SwiftUI

/// Read-only painting-state capsule for browse rows.
struct StateChip: View {
    let state: String
    let pipeline: [PipelineStage]
    var inherited: Bool = false

    private var hex: String { pipeline.first { $0.key == state }?.hex ?? "#888" }

    var body: some View {
        Text(state.isEmpty ? "—" : state)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .foregroundStyle(Color(hex: hex))
            .background(Color(hex: hex).opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Color(hex: hex).opacity(0.5)))
            .accessibilityLabel(inherited ? "Painting state \(state), inherited" : "Painting state \(state)")
    }
}
