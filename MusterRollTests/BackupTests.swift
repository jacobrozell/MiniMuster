import Testing
import SwiftData
@testable import MusterRoll

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
        let ctx = AppContainer.previewContainer().mainContext
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
}

@Suite("CollectionStore apply")
@MainActor
struct CollectionStoreTests {
    @Test("replace then append armies")
    func replaceAppend() throws {
        let ctx = AppContainer.previewContainer().mainContext
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
}
