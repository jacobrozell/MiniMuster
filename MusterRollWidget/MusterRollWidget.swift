import WidgetKit
import SwiftUI

struct SprueCountEntry: TimelineEntry {
    let date: Date
    let sprueModels: Int
    let totalModels: Int
}

struct SprueCountProvider: TimelineProvider {
    func placeholder(in context: Context) -> SprueCountEntry {
        SprueCountEntry(date: .now, sprueModels: 12, totalModels: 48)
    }

    func getSnapshot(in context: Context, completion: @escaping (SprueCountEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SprueCountEntry>) -> Void) {
        let entry = currentEntry()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> SprueCountEntry {
        SprueCountEntry(date: .now,
                        sprueModels: WidgetDataStore.sprueModelCount,
                        totalModels: WidgetDataStore.totalModelCount)
    }
}

struct SprueCountWidgetView: View {
    let entry: SprueCountEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("On the sprue", systemImage: "cube.box")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(entry.sprueModels)")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if entry.totalModels > 0 {
                Text("of \(entry.totalModels) models")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MusterRollWidget: Widget {
    let kind = "SprueCountWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SprueCountProvider()) { entry in
            SprueCountWidgetView(entry: entry)
        }
        .configurationDisplayName("On the Sprue")
        .description("Models still at the first pipeline stage.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

@main
struct MusterRollWidgetBundle: WidgetBundle {
    var body: some Widget {
        MusterRollWidget()
    }
}
