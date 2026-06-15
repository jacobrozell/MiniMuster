import Foundation
import Testing
import SwiftData
@testable import MiniMuster

@Suite("Backup sanitizer")
struct BackupSanitizerTests {
    /// A minimal web-shaped backup (version 3).
    let webBackup = """
    {
      "version": 3,
      "collection": [
        { "army": "Vermindoom", "game": "AoS", "faction": "Skaven",
          "crest": "SK", "color": "#8a9a4a",
          "units": [
            { "unit": "Clanrats (5)", "qty": 2, "source": "Skaventide", "state": "Based", "spearhead": true, "notes": "#wip" },
            { "unit": "Rat Ogors", "qty": 3, "state": "Assembled" }
          ] }
      ],
      "paints": [ { "name": "Khorne Red", "type": "Base", "swatch": "#7a7a7a", "qty": 1, "low": true } ],
      "settings": { "theme": "dark", "armySort": "csv", "quickView": "wip" },
      "exportedAt": "2026-06-14T00:00:00Z"
    }
    """

    @Test("parses a web-compatible backup and maps fields")
    func parse() throws {
        let result = BackupSanitizer.parse(webBackup)
        let backup = try #require(try? result.get())
        #expect(backup.armies.count == 1)
        #expect(backup.armies[0].units.count == 2)
        #expect(backup.armies[0].units[0].spearhead == true)
        #expect(backup.paints.count == 1)
        #expect(backup.paints[0].low == true)
        #expect(backup.settings.theme == .dark)
        #expect(backup.settings.armySort == "import")   // "csv" → "import"
        #expect(backup.settings.quickView == "wip")
        #expect(backup.preview.contains("1 armies"))
    }

    @Test("rejects unknown top-level keys")
    func strictKeys() {
        let r = BackupSanitizer.parse(#"{ "version": 3, "evil": true }"#)
        if case .failure(let err) = r { #expect(err == .unknownKeys(["evil"])) }
        else { Issue.record("expected failure") }
    }

    @Test("rejects non-object and invalid JSON")
    func badShapes() {
        if case .success = BackupSanitizer.parse("[]") { Issue.record("array should fail") }
        if case .success = BackupSanitizer.parse("not json") { Issue.record("garbage should fail") }
    }

    @Test("clamps strings and sanitizes colours")
    func clamp() throws {
        let json = """
        { "version": 3, "collection": [
          { "army": "A", "game": "40k", "faction": "Orks", "color": "javascript:alert(1)",
            "units": [ { "unit": "U", "state": "Primed" } ] } ],
          "paints": [], "settings": {} }
        """
        let backup = try #require(try? BackupSanitizer.parse(json).get())
        // invalid colour is not stored as an override (failed safeColor pattern → nil path)
        #expect(backup.armies[0].colorOverrideHex == nil || backup.armies[0].colorOverrideHex == "#888")
    }

    @Test("round-trips through the model graph")
    @MainActor
    func restoreRoundTrip() throws {
        let db = TestDatabase()
        let ctx = db.context
        let backup = try #require(try? BackupSanitizer.parse(webBackup).get())
        BackupCodec.restore(backup, into: ctx)

        let armies = try ctx.fetch(FetchDescriptor<Army>())
        #expect(armies.count == 1)
        #expect(armies[0].orderedUnits.count == 2)
        let paints = try ctx.fetch(FetchDescriptor<Paint>())
        #expect(paints.count == 1)
        #expect(Config.current(ctx).theme == .dark)

        // Re-export and re-parse: the collection survives a full round-trip.
        let json = BackupCodec.export(ctx)
        let again = try #require(try? BackupSanitizer.parse(json).get())
        #expect(again.armies.count == 1)
        #expect(again.armies[0].units.count == 2)
    }

    @Test("rejects backups over byte limit")
    func tooLarge() {
        let r = BackupSanitizer.parse("{}", byteLength: Limits.maxImportBytes + 1)
        if case .failure(let err) = r { #expect(err == .tooLarge(maxMB: 8)) }
        else { Issue.record("expected tooLarge") }
    }

    @Test("rejects collection over army, unit, and paint caps")
    func overLimit() {
        let manyArmies = Snapshot(version: 3,
            collection: (0..<(Limits.maxArmies + 1)).map {
                ArmyDTO(army: "A\($0)", game: "40k", faction: "Orks",
                        units: [UnitDTO(unit: "U", qty: 1, state: "Primed")])
            },
            paints: [], settings: nil, exportedAt: nil)
        if case .failure(.overLimit(let m)) = BackupSanitizer.sanitize(manyArmies) {
            #expect(m.contains("armies"))
        } else { Issue.record("expected army cap") }

        let bigArmy = Snapshot(version: 3,
            collection: [ArmyDTO(army: "A", game: "40k", faction: "Orks",
                units: (0..<(Limits.maxUnitsPerArmy + 1)).map { _ in
                    UnitDTO(unit: "U", qty: 1, state: "Primed")
                })],
            paints: [], settings: nil, exportedAt: nil)
        if case .failure(.overLimit(let m)) = BackupSanitizer.sanitize(bigArmy) {
            #expect(m.contains("unit entries"))
        } else { Issue.record("expected per-army cap") }

        let manyPaints = Snapshot(version: 3, collection: [],
            paints: (0..<(Limits.maxPaints + 1)).map { PaintDTO(name: "P\($0)", type: "Base") },
            settings: nil, exportedAt: nil)
        if case .failure(.overLimit(let m)) = BackupSanitizer.sanitize(manyPaints) {
            #expect(m.contains("paints"))
        } else { Issue.record("expected paint cap") }
    }

    @Test("sanitizes custom pipeline and squad members on restore")
    func membersAndPipeline() throws {
        let json = """
        { "version": 3, "collection": [
          { "army": "A", "game": "40k", "faction": "Orks",
            "pipeline": [ { "key": "Step1", "hex": "#111111" }, { "key": "Step2", "hex": "bad" } ],
            "units": [ { "unit": "Squad (2)", "qty": 1, "state": "Step1",
              "members": [ { "state": "Step2", "notes": "leader" }, { "state": null } ] } ] } ],
          "paints": [], "settings": { "quickView": "nope", "armySort": "csv" } }
        """
        let backup = try #require(try? BackupSanitizer.parse(json).get())
        #expect(backup.armies[0].customPipeline?.map(\.key) == ["Step1", "Step2"])
        #expect(backup.armies[0].units[0].members.count == 2)
        #expect(backup.armies[0].units[0].members[0].state == "Step2")
        #expect(backup.settings.quickView == "all")   // invalid value ignored
        #expect(backup.settings.armySort == "import")
    }

    @Test("export preserves settings, members, and web army sort mapping")
    @MainActor
    func exportSettings() throws {
        let db = TestDatabase()
        let ctx = db.context
        let army = Army(name: "GK", game: "40k", faction: "Grey Knights", sortIndex: 0)
        army.isCollapsed = true
        army.customPipeline = [PipelineStage(key: "A", hex: "#111111"),
                               PipelineStage(key: "B", hex: "#222222")]
        ctx.insert(army)
        let u = Unit(name: "Squad (2)", qty: 1, state: "A", order: 0)
        u.army = army; ctx.insert(u)
        SquadStore.enable(u, in: ctx)
        u.member(at: 0)?.state = "B"
        let paint = Paint(name: "Red", type: "Base", low: true); ctx.insert(paint)

        let cfg = Config.current(ctx)
        cfg.theme = .dark
        cfg.globalPipeline = DefaultPipeline.stages
        cfg.factionOverrides = [FactionPresetOverride(key: "40k:Grey Knights", crest: "GK2", hex: "#abcdef")]
        cfg.gameFilter = "40k"
        cfg.quickViewRaw = "wip"
        cfg.armySortRaw = "import"
        cfg.lastBackupAt = Date(timeIntervalSince1970: 0)
        try ctx.save()

        let json = BackupCodec.export(ctx)
        let backup = try #require(try? BackupSanitizer.parse(json).get())
        #expect(backup.settings.theme == .dark)
        #expect(backup.settings.gameFilter == "40k")
        #expect(backup.settings.quickView == "wip")
        #expect(backup.settings.armySort == "import")
        #expect(backup.settings.factionOverrides.first?.crest == "GK2")
        #expect(backup.armies.first?.customPipeline?.count == 2)
        #expect(backup.armies.first?.units.first?.members.count == 2)
        #expect(backup.paints.first?.low == true)

        let data = try #require(json.data(using: .utf8))
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
        #expect(snapshot.settings?.armySort == "csv")
        #expect(snapshot.settings?.collapsedArmies == ["GK"])
    }
}

@Suite("CollectionStore apply", .serialized)
@MainActor
struct CollectionStoreTests {
    @Test("replace then append armies")
    func replaceAppend() throws {
        let db = TestDatabase()
        let ctx = db.context
        let pipeline = DefaultPipeline.stages
        let csv = "Game,Faction,Army,Unit,Qty,State\n40k,Orks,W,Boyz (10),1,Primed\n"
        let first = ArmyCSV.import(CSV.parse(csv), pipeline: pipeline, overrides: [])
        CollectionStore.replaceArmies(first.armies ?? [], in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Army>()).count == 1)

        let csv2 = "Game,Faction,Army,Unit,State\n40k,Orks,W,Nob,Based\n40k,Orks,X,Grot,Primed\n"
        let second = ArmyCSV.import(CSV.parse(csv2), pipeline: pipeline, overrides: [])
        CollectionStore.appendArmies(second.armies ?? [], in: ctx)

        let armies = try ctx.fetch(FetchDescriptor<Army>())
        #expect(armies.count == 2)                                  // W merged, X added
        let w = armies.first { $0.name == "W" }
        #expect(w?.units.count == 2)                                // Boyz + Nob
    }

    @Test("replace and append paints merge by name")
    func paints() throws {
        let db = TestDatabase()
        let ctx = db.context
        CollectionStore.replacePaints([
            PaintDraft(name: "Khorne Red", qty: 2, notes: ""),
            PaintDraft(name: "Abaddon Black", qty: 1, notes: "matte"),
        ], in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Paint>()).count == 2)

        CollectionStore.appendPaints([
            PaintDraft(name: "khorne red", qty: 3, notes: "fav"),
            PaintDraft(name: "Contrast Medium", qty: 1, notes: ""),
        ], in: ctx)
        let paints = try ctx.fetch(FetchDescriptor<Paint>())
        #expect(paints.count == 3)
        let red = paints.first { $0.name == "Khorne Red" }
        #expect(red?.qty == 5)
        #expect(red?.notes == "fav")
    }

    @Test("clearAll wipes armies, paints, and resets configuration")
    func clearAll() throws {
        let db = TestDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Orks"); ctx.insert(army)
        let paint = Paint(name: "Red", type: "Base"); ctx.insert(paint)
        let cfg = Config.current(ctx)
        cfg.theme = .dark
        cfg.gameFilter = "40k"
        try ctx.save()

        CollectionStore.clearAll(in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Army>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<Paint>()).isEmpty)
        let fresh = Config.current(ctx)
        #expect(fresh.theme == .system)
        #expect(fresh.gameFilter == "All")
    }

    @Test("replaceArmies restores custom pipeline and squad members")
    func armyDraftDetails() throws {
        let db = TestDatabase()
        let ctx = db.context
        let draft = ArmyDraft(
            name: "A", game: "40k", faction: "Orks",
            crestOverride: "ORK", colorOverrideHex: "#ff0000",
            customPipeline: [PipelineStage(key: "Step1", hex: "#111111")],
            units: [UnitDraft(name: "Squad (2)", qty: 1, state: "Step1",
                              members: [MemberDraft(state: "Step1"), MemberDraft(state: nil)])])
        CollectionStore.replaceArmies([draft], in: ctx)
        let army = try #require((try? ctx.fetch(FetchDescriptor<Army>()))?.first)
        #expect(army.crestOverride == "ORK")
        #expect(army.customPipeline?.first?.key == "Step1")
        #expect(army.orderedUnits.first?.members.count == 2)
    }
}
