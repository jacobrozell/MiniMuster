import Foundation
import Testing
import SwiftData
@testable import MusterRoll

@Suite("DataActions", .serialized)
@MainActor
struct DataActionsTests {
    private func tempFile(named name: String, contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func tempFile(named name: String, data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    @Test("readText loads UTF-8 and rejects oversized files")
    func readText() throws {
        let url = try tempFile(named: "small.csv", contents: "a,b\n1,2\n")
        #expect(try DataActions.readText(at: url) == "a,b\n1,2\n")

        let big = Data(repeating: 0x41, count: Limits.maxImportBytes + 1)
        let bigURL = try tempFile(named: "big.txt", data: big)
        #expect(throws: DataActions.Failure.self) {
            _ = try DataActions.readText(at: bigURL)
        }
    }

    @Test("importArmiesOutcome replace replaces the collection")
    func importArmiesReplace() throws {
        let db = TestDatabase()
        let ctx = db.context
        let army = Army(name: "Old", game: "40k", faction: "Orks"); ctx.insert(army)
        try ctx.save()

        let csv = """
        Game,Faction,Army,Unit,Qty,State
        40k,Orks,WAAAGH,Boyz (10),1,Primed
        """
        let url = try tempFile(named: "armies.csv", contents: csv)
        let outcome = DataActions.importArmiesOutcome(from: url, mode: .replace, ctx: ctx)

        #expect(outcome.success)
        let armies = try ctx.fetch(FetchDescriptor<Army>())
        #expect(armies.count == 1)
        #expect(armies.first?.name == "WAAAGH")
        #expect(armies.first?.orderedUnits.first?.name == "Boyz (10)")
    }

    @Test("importArmiesOutcome append merges units into an existing army")
    func importArmiesAppend() throws {
        let db = TestDatabase()
        let ctx = db.context
        let army = Army(name: "WAAAGH", game: "40k", faction: "Orks"); ctx.insert(army)
        let unit = Unit(name: "Boyz (10)", qty: 1, state: "Primed", order: 0)
        unit.army = army; ctx.insert(unit)
        try ctx.save()

        let csv = "Game,Faction,Army,Unit,State\n40k,Orks,WAAAGH,Nob,Based\n"
        let url = try tempFile(named: "append-armies.csv", contents: csv)
        let outcome = DataActions.importArmiesOutcome(from: url, mode: .append, ctx: ctx)

        #expect(outcome.success)
        #expect(army.orderedUnits.count == 2)
        #expect(army.orderedUnits.map(\.name) == ["Boyz (10)", "Nob"])
    }

    @Test("importPaintsOutcome replace and append merge by name")
    func importPaints() throws {
        let db = TestDatabase()
        let ctx = db.context
        PaintStore.add(name: "Leadbelcher", type: "Base", brand: "", source: "",
                       qty: 1, notes: "", low: false, in: ctx)

        let replaceCSV = "Name,Type\nKhorne Red,Base\n"
        let replaceURL = try tempFile(named: "paints-replace.csv", contents: replaceCSV)
        let replaced = DataActions.importPaintsOutcome(from: replaceURL, mode: .replace, ctx: ctx)
        #expect(replaced.success)
        #expect(try ctx.fetch(FetchDescriptor<Paint>()).map(\.name) == ["Khorne Red"])

        let appendCSV = """
        Name,Type,Quantity,Notes
        khorne red,Base,2,fav
        Abaddon Black,Base,1,
        """
        let appendURL = try tempFile(named: "paints-append.csv", contents: appendCSV)
        let appended = DataActions.importPaintsOutcome(from: appendURL, mode: .append, ctx: ctx)
        #expect(appended.success)
        let paints = try ctx.fetch(FetchDescriptor<Paint>())
        #expect(paints.count == 2)
        let red = paints.first { $0.name == "Khorne Red" }
        #expect(red?.qty == 3)
        #expect(red?.notes == "fav")
    }

    @Test("string import helpers surface CSV and restore failures")
    func stringImports() throws {
        let db = TestDatabase()
        let ctx = db.context
        let badArmyURL = try tempFile(named: "bad-armies.csv", contents: "Game,Faction,Army\n")
        #expect(DataActions.importArmies(from: badArmyURL, mode: .replace, ctx: ctx)
            .contains("Import failed"))

        let xlsxURL = try tempFile(named: "roster.xlsx", contents: "ignored")
        #expect(DataActions.importPaints(from: xlsxURL, mode: .replace, ctx: ctx).contains("Excel"))

        let badBackupURL = try tempFile(named: "bad.json", contents: "[]")
        #expect(DataActions.restoreBackup(from: badBackupURL, ctx: ctx).contains("JSON object"))

        let garbageURL = try tempFile(named: "garbage.json", contents: "not json")
        #expect(DataActions.restoreBackup(from: garbageURL, ctx: ctx).contains("Invalid JSON"))
    }

    @Test("restoreBackupOutcome restores a valid backup")
    func restoreBackup() throws {
        let db = TestDatabase()
        let ctx = db.context
        let json = """
        { "version": 3, "collection": [
          { "army": "W", "game": "40k", "faction": "Orks",
            "units": [ { "unit": "Boyz (5)", "qty": 1, "state": "Primed" } ] } ],
          "paints": [ { "name": "Red", "type": "Base" } ], "settings": {} }
        """
        let url = try tempFile(named: "backup.json", contents: json)
        let outcome = DataActions.restoreBackupOutcome(from: url, ctx: ctx)

        #expect(outcome.success)
        #expect(try ctx.fetch(FetchDescriptor<Army>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<Paint>()).count == 1)
    }

    @Test("loadSampleOutcome loads bundled sample CSVs")
    func loadSample() {
        let db = TestDatabase()
        let ctx = db.context
        let outcome = DataActions.loadSampleOutcome(ctx: ctx)
        #expect(outcome.success)
        #expect(outcome.message.contains("armies"))
        #expect(((try? ctx.fetch(FetchDescriptor<Army>())) ?? []).isEmpty == false)
        #expect(((try? ctx.fetch(FetchDescriptor<Paint>())) ?? []).isEmpty == false)
        #expect(DataActions.loadSample(ctx: ctx).contains("Sample loaded"))
    }

    @Test("template builders match CSVSchema and import from disk")
    func templateExports() throws {
        let armies = DataActions.armiesTemplateCSV()
        #expect(armies.text == CSVSchema.template(.armies))
        #expect(armies.filename == CSVSchema.filename(.armies))

        let paints = DataActions.paintsTemplateCSV()
        #expect(paints.text == CSVSchema.template(.paints))
        #expect(paints.filename == CSVSchema.filename(.paints))

        let db = TestDatabase()
        let ctx = db.context

        let armyURL = try tempFile(named: armies.filename, contents: armies.text)
        let armyOutcome = DataActions.importArmiesOutcome(from: armyURL, mode: .replace, ctx: ctx)
        #expect(armyOutcome.success)
        #expect(try ctx.fetch(FetchDescriptor<Army>()).first?.name == "My Chapter")

        let paintURL = try tempFile(named: paints.filename, contents: paints.text)
        let paintOutcome = DataActions.importPaintsOutcome(from: paintURL, mode: .replace, ctx: ctx)
        #expect(paintOutcome.success)
        #expect(try ctx.fetch(FetchDescriptor<Paint>()).first?.name == "Macragge Blue")
    }

    @Test("export builders produce expected filenames and content")
    func exports() throws {
        let db = TestDatabase()
        let ctx = db.context
        let army = Army(name: "W", game: "40k", faction: "Orks"); ctx.insert(army)
        let unit = Unit(name: "Boyz (5)", qty: 1, state: "Primed", order: 0)
        unit.army = army; ctx.insert(unit)
        ctx.insert(Paint(name: "Red", type: "Base"))
        try ctx.save()

        let armies = DataActions.armiesCSV(ctx: ctx)
        #expect(armies.filename.hasPrefix("warhammer_armies_"))
        #expect(armies.text.contains("Boyz (5)"))

        let paints = DataActions.paintsCSV(ctx: ctx)
        #expect(paints.filename.hasPrefix("warhammer_paint_inventory_"))
        #expect(paints.text.contains("Red"))

        let backup = DataActions.backupJSON(ctx: ctx)
        #expect(backup.filename.hasPrefix("minimuster-backup-"))
        #expect(backup.text.contains("\"version\""))
        #expect(Config.current(ctx).lastBackupAt != nil)
    }

    @Test("import outcome surfaces warnings without treating them as failures")
    func importWarnings() throws {
        let db = TestDatabase()
        let ctx = db.context
        let csv = "Game,Faction,Army,Unit,State\n40k,Squats,Hold,Warrior (5),Glazed\n"
        let url = try tempFile(named: "warn.csv", contents: csv)
        let outcome = DataActions.importArmiesOutcome(from: url, mode: .replace, ctx: ctx)
        #expect(outcome.success)
        #expect(!outcome.warnings.isEmpty)
        #expect(outcome.message.contains("warning"))
    }

    @Test("import armies rejects Excel filenames before reading")
    func excelHint() throws {
        let db = TestDatabase()
        let ctx = db.context
        let url = try tempFile(named: "roster.xlsx", contents: "ignored")
        let outcome = DataActions.importArmiesOutcome(from: url, mode: .replace, ctx: ctx)
        #expect(!outcome.success)
        #expect(outcome.message.contains("Excel"))
    }
}
