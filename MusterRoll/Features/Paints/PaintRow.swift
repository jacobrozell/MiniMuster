import SwiftUI

/// Read-only paint row for list layout.
struct PaintRow: View {
    let paint: Paint
    let linkedCount: Int

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: paint.swatchHex))
                .frame(width: 28, height: 28)
                .fixedSize()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(paint.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                    if paint.low {
                        Text("LOW")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.orange.opacity(0.2), in: Capsule())
                            .fixedSize()
                    }
                }
                let meta = [paint.type, paint.brand].filter { !$0.isEmpty }.joined(separator: " · ")
                if !meta.isEmpty {
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if !paint.source.isEmpty {
                    Text("\(paint.source)\(linkedCount > 0 ? " (\(linkedCount) units)" : "")")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            if paint.qty > 1 {
                Text("×\(paint.qty)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize()
                    .layoutPriority(-1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(paint.name), \(paint.type), quantity \(paint.qty)")
    }
}
