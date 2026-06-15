import SwiftUI

/// Browse row for one army in the collection list.
struct ArmyRow: View {
    let army: Army
    let overrides: [FactionPresetOverride]
    let visibleUnitCount: Int
    let percentComplete: Int
    let scoped: Bool

    private var presentation: (crest: String, colorHex: String) {
        army.presentation(overrides: overrides)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CrestBadge(text: presentation.crest, colorHex: presentation.colorHex)
                .fixedSize()
            VStack(alignment: .leading, spacing: 2) {
                Text(army.name)
                    .font(.headline)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            ProgressRing(percent: percentComplete)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(army.name), \(army.faction), \(percentComplete) percent complete, \(visibleUnitCount) units")
        .accessibilityHint("Opens army details")
    }

    private var subtitle: String {
        let countLabel = scoped ? "\(visibleUnitCount) visible" : "\(visibleUnitCount) units"
        var parts = [army.game, army.faction, countLabel]
        if army.customPipeline?.isEmpty == false { parts.append("custom pipeline") }
        return parts.joined(separator: " · ")
    }
}
