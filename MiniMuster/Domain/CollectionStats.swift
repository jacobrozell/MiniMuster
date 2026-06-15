import Foundation

/// Collection summary numbers for the armies tab header. Keeps stat maths out of SwiftUI.
enum CollectionStats {
    struct Snapshot: Equatable {
        var unitEntries: Int
        var models: Int
        var based: Int
        var done: Int
        var wip: Int
        var todo: Int
        var overallPercent: Int
        var segments: [ProgressSegment]
    }

    static func basedStage(in pipeline: [PipelineStage]) -> PipelineStage? {
        pipeline.first { $0.key == "Based" }
            ?? (pipeline.count >= 2 ? pipeline[pipeline.count - 2] : nil)
    }

    static func doneStage(in pipeline: [PipelineStage]) -> PipelineStage? {
        pipeline.first { $0.key == "Done" } ?? pipeline.last
    }

    static func snapshot(units: [Unit], pipeline: [PipelineStage]) -> Snapshot {
        let models = units.reduce(0) { $0 + $1.modelCount }
        let basedKey = basedStage(in: pipeline)?.key
        let doneKey = doneStage(in: pipeline)?.key
        let based = basedKey.map { key in units.filter { $0.state == key }.count } ?? 0
        let done = doneKey.map { key in units.filter { $0.state == key }.count } ?? 0
        let first = pipeline.first?.key
        let wip = units.filter { !Pipeline.doneStates.contains($0.state) && $0.state != first }.count
        let todo = units.filter { $0.state == first }.count
        let overall = Int((Pipeline.progress(of: units, pipeline) * 100).rounded())
        let segments = Pipeline.segments(of: units, pipeline)
        return Snapshot(unitEntries: units.count, models: models, based: based, done: done,
                        wip: wip, todo: todo, overallPercent: overall, segments: segments)
    }
}
