import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Read-only paint row for list layout.
struct PaintRow: View {
    let paint: Paint
    let linkedCount: Int

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
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = ["\(paint.name)", paint.type, "quantity \(paint.qty)"]
        if paint.low { parts.append("running low") }
        if linkedCount > 0 { parts.append("\(linkedCount) linked units") }
        return parts.joined(separator: ", ")
    }

    private var swatch: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(hex: paint.swatchHex))
            .frame(width: 28, height: 28)
            .fixedSize()
            .accessibilityHidden(true)
    }

    private var horizontalRow: some View {
        HStack(alignment: .center, spacing: 12) {
            swatch
            textBlock
            qtyLabel
        }
    }

    private var stackedRow: some View {
        HStack(alignment: .top, spacing: 12) {
            swatch
            VStack(alignment: .leading, spacing: 3) {
                textBlock
                qtyLabel
            }
        }
    }

    @ViewBuilder
    private var qtyLabel: some View {
        if paint.qty > 1 {
            Text("×\(paint.qty)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .fixedSize()
        }
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(paint.name)
                    .font(.headline)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
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
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            if !paint.source.isEmpty {
                Text("\(paint.source)\(linkedCount > 0 ? " (\(linkedCount) units)" : "")")
                    .font(.caption2)
                    .foregroundStyle(.tint)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
