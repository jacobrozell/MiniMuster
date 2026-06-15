import SwiftUI

struct OwnershipBadge: View {
    let status: CollectionMatchResult.Status

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(color)
            .accessibilityLabel(label)
    }

    private var symbol: String {
        switch status {
        case .owned: "checkmark.circle.fill"
        case .partial: "minus.circle.fill"
        case .missing: "plus.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private var color: Color {
        switch status {
        case .owned: .green
        case .partial: .orange
        case .missing: .red
        case .unknown: .secondary
        }
    }

    private var label: String {
        switch status {
        case .owned: "Owned in collection"
        case .partial: "Partially owned"
        case .missing: "Missing from collection"
        case .unknown: "Collection match unknown"
        }
    }
}
