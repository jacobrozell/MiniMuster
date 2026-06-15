import Foundation
import WidgetKit

#if canImport(SwiftData)
import SwiftData
#endif

/// Pushes collection stats into the shared App Group for WidgetKit.
@MainActor
enum WidgetUpdater {
#if canImport(SwiftData)
    static func refresh(context: ModelContext) {
        let armies = (try? context.fetch(FetchDescriptor<Army>())) ?? []
        let cfg = (try? context.fetch(FetchDescriptor<AppConfiguration>()))?.first
        refresh(armies: armies, globalPipeline: cfg?.globalPipeline)
    }

    static func refresh(armies: [Army], globalPipeline: [PipelineStage]?) {
        let units = armies.flatMap(\.units)
        let pipeline = Pipeline.resolve(globalPipeline)
        let first = pipeline.first?.key ?? "Unassembled"
        let sprue = units.filter { $0.state == first }.reduce(0) { $0 + $1.modelCount }
        let total = units.reduce(0) { $0 + $1.modelCount }
        WidgetDataStore.write(sprueModelCount: sprue, totalModelCount: total)
        WidgetCenter.shared.reloadAllTimelines()
    }
#endif
}
