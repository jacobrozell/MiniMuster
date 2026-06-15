import SwiftUI

struct RosterPointsBar: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let roster: Roster
    private var total: Int { RosterPoints.total(roster.orderedEntries) }
    private var limit: Int { RosterPoints.limit(for: roster) }
    private var remaining: Int { RosterPoints.remaining(for: roster) }
    private var over: Bool { RosterPoints.isOverLimit(roster) }
    private var compactHeight: Bool { verticalSizeClass == .compact }

    var body: some View {
        VStack(spacing: compactHeight ? 4 : 8) {
            ProgressView(value: RosterPoints.fillFraction(roster))
                .tint(over ? .red : .accentColor)
            if compactHeight && dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    pointsSummary
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                pointsSummary
            }
        }
        .padding(.horizontal)
        .padding(.vertical, compactHeight ? 8 : 12)
        .background(.bar)
        .accessibilityIdentifier("rosterPointsBar")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var pointsSummary: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(total)")
                .font(compactHeight ? .headline : .title3.weight(.semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text("pts used")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Spacer()
            if limit > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("of \(limit)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(over ? .red : .secondary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    if !over {
                        Text("\(remaining) left")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    } else {
                        Text("\(-remaining) over")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.red)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var accessibilitySummary: String {
        guard limit > 0 else { return "Points \(total), no limit" }
        if over { return "Points \(total) of \(limit), over limit by \(-remaining)" }
        return "Points \(total) of \(limit), \(remaining) remaining"
    }
}
