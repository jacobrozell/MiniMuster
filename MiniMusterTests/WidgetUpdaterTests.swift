import Foundation
import Testing
import SwiftData
@testable import MiniMuster

@Suite("WidgetUpdater", .serialized)
@MainActor
struct WidgetUpdaterTests {
    func expectedCounts(armies: [Army], globalPipeline: [PipelineStage]?) -> (sprue: Int, total: Int) {
        let units = armies.flatMap(\.units)
        let pipeline = Pipeline.resolve(globalPipeline)
        let first = pipeline.first?.key ?? "Unassembled"
        let sprue = units.filter { $0.state == first }.reduce(0) { $0 + $1.modelCount }
        let total = units.reduce(0) { $0 + $1.modelCount }
        return (sprue, total)
    }

    @Test("counts sprue models in the first pipeline stage")
    func sprueCount() throws {
        let db = TestDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        let onSprue = Unit(name: "Boyz (5)", qty: 1, state: "Unassembled", order: 0)
        let built = Unit(name: "Nob", qty: 1, state: "Primed", order: 1)
        onSprue.army = army; built.army = army
        ctx.insert(onSprue); ctx.insert(built)
        try ctx.save()

        let armies = try ctx.fetch(FetchDescriptor<Army>())
        let expected = expectedCounts(armies: armies, globalPipeline: nil)
        #expect(expected.sprue == 5)
        #expect(expected.total == 6)

        WidgetUpdater.refresh(armies: armies, globalPipeline: nil)
        if Foundation.UserDefaults(suiteName: WidgetDataStore.appGroupID) != nil {
            #expect(WidgetDataStore.sprueModelCount == 5)
            #expect(WidgetDataStore.totalModelCount == 6)
        }
    }

    @Test("custom global pipeline changes which stage counts as sprue")
    func customPipeline() throws {
        let db = TestDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        let u = Unit(name: "Boyz (3)", qty: 1, state: "A", order: 0)
        u.army = army; ctx.insert(u)
        try ctx.save()

        let custom = [PipelineStage(key: "A", hex: "#111111"),
                      PipelineStage(key: "B", hex: "#222222")]
        let armies = try ctx.fetch(FetchDescriptor<Army>())
        let expected = expectedCounts(armies: armies, globalPipeline: custom)
        #expect(expected.sprue == 3)
        #expect(expected.total == 3)
    }
}
