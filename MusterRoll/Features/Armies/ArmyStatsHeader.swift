import SwiftUI

/// Collection stats tiles + overall progress meter. Mirrors `renderArmyStats`.
/// `units`/`armyCount` are the scoped set when filters are active; `scoped` adds the
/// "(filtered)" labels.
struct ArmyStatsHeader: View {
    let units: [Unit]
    let armyCount: Int
    let pipeline: [PipelineStage]
    var scoped: Bool = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var statColumns: [GridItem] {
        if dynamicTypeSize >= .accessibility5 {
            [GridItem(.flexible())]
        } else if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        } else {
            [GridItem(.adaptive(minimum: 108), spacing: 8)]
        }
    }

    private func label(_ base: String) -> String { scoped ? "\(base) (filtered)" : base }

    var body: some View {
        let u = units
        let models = u.reduce(0) { $0 + $1.modelCount }
        let based = u.filter { $0.state == "Based" }.count
        let done = u.filter { $0.state == "Done" }.count
        let first = pipeline.first?.key
        let wip = u.filter { !Pipeline.doneStates.contains($0.state) && $0.state != first }.count
        let todo = u.filter { $0.state == first }.count
        let overall = Int((Pipeline.progress(of: u, pipeline) * 100).rounded())

        VStack(spacing: 12) {
            LazyVGrid(columns: statColumns, spacing: 8) {
                StatTile(value: u.count, label: label("Unit Entries"))
                StatTile(value: models, label: label("Models (est.)"), accent: true)
                StatTile(value: based, label: label("Based"))
                StatTile(value: done, label: label("Done"))
                StatTile(value: wip, label: "In Progress")
                StatTile(value: todo, label: "On the Sprue")
                StatTile(value: armyCount, label: label("Armies"))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(scoped ? "Filtered progress (by model count)" : "Collection progress (by model count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text("\(overall)%")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .fixedSize()
                }
                ProgressMeter(segments: Pipeline.segments(of: u, pipeline))
                ProgressLegend(segments: Pipeline.segments(of: u, pipeline))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Collection progress \(overall) percent")
        }
    }
}

/// Wrapping legend of swatch + stage name under the collection meter.
struct ProgressLegend: View {
    let segments: [ProgressSegment]

    var body: some View {
        if !segments.isEmpty {
            FlowText(segments: segments)
        }
    }
}

/// Simple wrapping row of legend chips.
private struct FlowText: View {
    let segments: [ProgressSegment]
    var body: some View {
        ViewThatFits(in: .horizontal) {
            row
            ScrollView(.horizontal, showsIndicators: false) { row }
        }
    }
    private var row: some View {
        HStack(spacing: 10) {
            ForEach(segments) { seg in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: seg.hex)).frame(width: 8, height: 8)
                    Text(seg.key).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}
