import SwiftUI
import SwiftData

struct RosterEntryRow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(AppRouter.self) private var router
    @Query private var armies: [Army]

    let entry: RosterEntry
    let roster: Roster
    var match: CollectionMatchResult?
    var onTap: (() -> Void)?

    private var catalog: CatalogUnit? { UnitCatalogLoader.unit(id: entry.catalogUnitId) }
    private var largeText: Bool { dynamicTypeSize.isAccessibilitySize }
    private var compactHeight: Bool { verticalSizeClass == .compact }
    private var usesStackedLayout: Bool { largeText || compactHeight }

    var body: some View {
        Group {
            if usesStackedLayout { stackedRow } else { compactRow }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .contain)
        .accessibilityHint("Opens unit options")
    }

    private var compactRow: some View {
        HStack(alignment: .center, spacing: 10) {
            nameBlock
            Spacer(minLength: 4)
            ownershipControl
            Text("\(entry.pointsTotal)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(entry.pointsTotal) points")
            qtyStepper
        }
    }

    private var stackedRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.displayName)
                    .font(.body)
                    .lineLimit(3)
                Spacer(minLength: 8)
                ownershipControl
                Text("\(entry.pointsTotal) pts")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack {
                if let catalog {
                    Text(modelCountLabel(catalog.modelCount, category: catalog.category))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                qtyStepper
            }
        }
    }

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.displayName)
                .font(.body)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            if let catalog {
                Text(modelCountLabel(catalog.modelCount, category: catalog.category))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(nameAccessibilityLabel)
    }

    @ViewBuilder
    private var ownershipControl: some View {
        if let match {
            Button { openCollection(for: match) } label: {
                OwnershipBadge(status: match.status)
            }
            .buttonStyle(.plain)
            .accessibilityHint(ownershipHint(for: match.status))
            .disabled(match.status == .missing || match.status == .unknown)
        }
    }

    @ViewBuilder
    private var qtyStepper: some View {
        if usesStackedLayout {
            Stepper("Qty \(entry.qty)", value: Binding(
                get: { entry.qty },
                set: { RosterStore.setQty(entry, $0, in: context) }
            ), in: 1...Limits.maxRosterQty)
            .accessibilityLabel("Quantity")
            .accessibilityValue("\(entry.qty)")
        } else {
            Stepper(value: Binding(
                get: { entry.qty },
                set: { RosterStore.setQty(entry, $0, in: context) }
            ), in: 1...Limits.maxRosterQty) {
                EmptyView()
            }
            .labelsHidden()
            .accessibilityLabel("Quantity")
            .accessibilityValue("\(entry.qty)")
        }
    }

    private var nameAccessibilityLabel: String {
        var parts = [entry.displayName, "\(entry.pointsTotal) points"]
        if let catalog {
            parts.append(modelCountLabel(catalog.modelCount, category: catalog.category))
        }
        if let match {
            parts.append(ownershipHint(for: match.status))
        }
        return parts.joined(separator: ", ")
    }

    private func modelCountLabel(_ count: Int, category: String) -> String {
        let noun = count == 1 ? "model" : "models"
        return "\(count) \(noun) · \(category)"
    }

    private func ownershipHint(for status: CollectionMatchResult.Status) -> String {
        switch status {
        case .owned, .partial: "Owned in collection, opens in Collection tab"
        case .missing: "Missing from collection"
        case .unknown: "Collection match unknown"
        }
    }

    private func openCollection(for match: CollectionMatchResult) {
        guard match.status == .owned || match.status == .partial,
              let unitId = match.matchedUnitIds.first,
              let armyId = armies.flatMap(\.units).first(where: { $0.id == unitId })?.army?.id
        else { return }
        router.openCollection(armyId: armyId, unitId: unitId)
    }
}
