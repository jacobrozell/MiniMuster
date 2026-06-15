import Foundation
import SwiftData
import Testing
@testable import MusterRoll

@Suite("CollectionStats")
struct CollectionStatsTests {
    let pipeline = DefaultPipeline.stages

    @Test("based and done stages fall back sensibly on custom pipelines")
    func stages() {
        #expect(CollectionStats.basedStage(in: pipeline)?.key == "Based")
        #expect(CollectionStats.doneStage(in: pipeline)?.key == "Done")

        let custom = [PipelineStage(key: "A", hex: "#111111"),
                      PipelineStage(key: "B", hex: "#222222")]
        #expect(CollectionStats.basedStage(in: custom)?.key == "A")
        #expect(CollectionStats.doneStage(in: custom)?.key == "B")
    }

    @Test("snapshot counts unit entries, models, and pipeline buckets")
    func snapshot() {
        let onSprue = Unit(name: "Boyz (5)", qty: 1, state: "Unassembled")
        let based = Unit(name: "Nob", qty: 1, state: "Based")
        let done = Unit(name: "Warboss", qty: 1, state: "Done")
        let wip = Unit(name: "Grot", qty: 1, state: "Primed")

        let stats = CollectionStats.snapshot(units: [onSprue, based, done, wip], pipeline: pipeline)

        #expect(stats.unitEntries == 4)
        #expect(stats.models == 8)
        #expect(stats.based == 1)
        #expect(stats.done == 1)
        #expect(stats.todo == 1)
        #expect(stats.wip == 1)
        #expect(stats.overallPercent > 0)
        #expect(!stats.segments.isEmpty)
    }
}

@Suite("AppRouter")
@MainActor
struct AppRouterTests {
    @Test("showArmies switches tab and queues a source filter")
    func showArmies() {
        let router = AppRouter()
        router.collectionSearch = "existing"
        router.showArmies(filteredBySource: "Combat Patrol")
        #expect(router.tab == .armies)
        #expect(router.pendingSourceFilter == "Combat Patrol")
        #expect(router.collectionSearch == "existing")
    }
}

@Suite("AppInfo")
struct AppInfoTests {
    @Test("detects UI testing launch arguments")
    func uiTesting() {
        #expect(AppInfo.displayName == "MiniMuster")
    }
}

@Suite("AppContainer")
@MainActor
struct AppContainerTests {
    @Test("preview container seeds a configuration row")
    func configuration() throws {
        let container = AppContainer.previewContainer()
        let ctx = container.mainContext
        let configs = try ctx.fetch(FetchDescriptor<AppConfiguration>())
        #expect(configs.count == 1)
    }
}

@Suite("DemoLoader")
@MainActor
struct DemoLoaderTests {
    @Test("bundled sample CSVs are present in the app bundle")
    func bundledResources() {
        #expect(DemoLoader.bundledCSV("warhammer_armies")?.contains("Game,Faction,Army") == true)
        #expect(DemoLoader.bundledCSV("warhammer_paint_inventory")?.contains("Name,Type") == true)
    }

    @Test("load replaces the in-memory collection")
    func load() throws {
        let db = TestDatabase()
        let ctx = db.context
        ctx.insert(Army(name: "Old", game: "40k", faction: "Orks"))
        try ctx.save()

        let counts = try DemoLoader.load(into: ctx)
        #expect(counts.armies > 0)
        #expect(counts.paints > 0)
        #expect(try ctx.fetch(FetchDescriptor<Army>()).contains { $0.name == "Old" } == false)
    }
}

@Suite("WidgetDataStore")
struct WidgetDataStoreTests {
    @Test("writes and reads sprue and total counts in the app group")
    func roundTrip() {
        WidgetDataStore.write(sprueModelCount: 12, totalModelCount: 34)
        if UserDefaults(suiteName: WidgetDataStore.appGroupID) != nil {
            #expect(WidgetDataStore.sprueModelCount == 12)
            #expect(WidgetDataStore.totalModelCount == 34)
        }
    }
}

@Suite("Army presentation")
struct ArmyPresentationTests {
    @Test("uses overrides when set, otherwise resolves from the catalogue")
    func presentation() {
        let army = Army(name: "GK", game: "40k", faction: "Grey Knights")
        let base = army.presentation(overrides: [])
        #expect(base.crest == "GK")

        army.crestOverride = "MINE"
        army.colorOverrideHex = "#123456"
        let custom = army.presentation(overrides: [])
        #expect(custom.crest == "MINE")
        #expect(custom.colorHex == "#123456")
    }
}
