import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

    private var usesStackedLayout: Bool {
#if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
#else
        false
#endif
    }

    var body: some View {
        Group {
            if usesStackedLayout {
                stackedRow
            } else {
                horizontalRow
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(army.name), \(army.faction), \(percentComplete) percent complete, \(visibleUnitCount) units")
        .accessibilityHint("Opens army details")
    }

    private var horizontalRow: some View {
        HStack(alignment: .center, spacing: 12) {
            crest
            textBlock
            ProgressRing(percent: percentComplete, diameter: 32)
        }
    }

    private var stackedRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                crest
                Spacer(minLength: 0)
                ProgressRing(percent: percentComplete, diameter: 32)
            }
            textBlock
        }
    }

    private var crest: some View {
        CrestBadge(text: presentation.crest, colorHex: presentation.colorHex)
            .fixedSize()
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(army.name)
                .font(.headline)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        let countLabel = scoped ? "\(visibleUnitCount) visible" : "\(visibleUnitCount) units"
        var parts = [army.game, army.faction, countLabel]
        if army.customPipeline?.isEmpty == false { parts.append("custom pipeline") }
        return parts.joined(separator: " · ")
    }
}
