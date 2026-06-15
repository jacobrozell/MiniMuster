import SwiftUI

/// Optional grid layout for paints.
struct PaintGridView: View {
    let paints: [Paint]
    let linkedCount: (Paint) -> Int
    let onSelect: (Paint) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize >= .accessibility3 {
            [GridItem(.flexible())]
        } else if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.adaptive(minimum: 180), spacing: 12)]
        } else {
            [GridItem(.adaptive(minimum: 140), spacing: 12)]
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(paints) { paint in
                Button { onSelect(paint) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: paint.swatchHex))
                            .frame(height: 44)
                        Text(paint.name)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if paint.low {
                            Text("LOW").font(.caption2.bold()).foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(gridAccessibilityLabel(for: paint))
                .accessibilityHint("Opens paint details")
            }
        }
        .padding(.horizontal)
    }

    private func gridAccessibilityLabel(for paint: Paint) -> String {
        var parts = [paint.name, paint.type, "quantity \(paint.qty)"]
        if paint.low { parts.append("running low") }
        let linked = linkedCount(paint)
        if linked > 0 { parts.append("\(linked) linked units") }
        return parts.joined(separator: ", ")
    }
}
