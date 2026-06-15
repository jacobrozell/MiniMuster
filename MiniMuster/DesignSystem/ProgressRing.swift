import SwiftUI

/// Circular completion indicator for army browse rows.
struct ProgressRing: View {
    let percent: Int
    var diameter: CGFloat = 36

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var scaledSmall: CGFloat = 36
    @ScaledMetric(relativeTo: .title2) private var scaledLarge: CGFloat = 88

    private var size: CGFloat {
        if diameter <= 36 { return min(scaledSmall, 52) }
        return min(scaledLarge, 120)
    }

    var body: some View {
        Gauge(value: Double(percent), in: 0...100) {
            EmptyView()
        } currentValueLabel: {
            Text("\(percent)")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .frame(width: size, height: size)
        .fixedSize()
        .layoutPriority(-1)
        .animation(reduceMotion ? nil : .default, value: percent)
        .accessibilityLabel("\(percent) percent complete")
    }
}
