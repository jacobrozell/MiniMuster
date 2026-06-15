import SwiftUI
import SwiftData

/// Chronological painting progress for a unit (stage changes and future photo checkpoints).
struct UnitTimelineSection: View {
    let unit: Unit
    let pipeline: [PipelineStage]

    private var events: [StageEvent] {
        unit.orderedStageEvents
    }

    var body: some View {
        if !events.isEmpty {
            Section("Timeline") {
                ForEach(events) { event in
                    timelineRow(event)
                }
            }
        }
    }

    @ViewBuilder
    private func timelineRow(_ event: StageEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    StateChip(state: event.stageKey, pipeline: pipeline)
                    if let index = event.memberIndex {
                        Text("#\(index + 1)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let previous = event.previousStageKey, previous != event.stageKey {
                    Text("from \(previous)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            if let thumb = photoNear(event) {
                UnitPhotoThumb(photo: thumb)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Photo captured at the same stage, closest in time to the event (if any).
    private func photoNear(_ event: StageEvent) -> ModelPhoto? {
        let candidates = unit.orderedPhotos.filter {
            $0.stageKey == event.stageKey
            && (event.memberIndex == nil || $0.memberIndex == event.memberIndex)
        }
        return candidates.min {
            abs($0.createdAt.timeIntervalSince(event.occurredAt))
            < abs($1.createdAt.timeIntervalSince(event.occurredAt))
        }
    }
}
