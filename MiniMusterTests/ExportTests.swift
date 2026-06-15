import Foundation
import Testing
import SwiftData
@testable import MiniMuster

@Suite("Army CSV export", .serialized)
@MainActor
struct ArmyExportTests {
    @Test("exports unit rows with crest, colour, and spearhead")
    func unitRow() throws {
        let db = TestDatabase()
        let ctx = db.context
        let army = Army(name: "GK", game: "40k", faction: "Grey Knights", sortIndex: 0)
        army.crestOverride = "MINE"
        army.colorOverrideHex = "#112233"
        ctx.insert(army)
        let u = Unit(name: "Strike (5)", qty: 2, source: "Combat Patrol", state: "Primed",
                     notes: "#wip", spearhead: true, order: 0)
        u.army = army; ctx.insert(u)
        try ctx.save()

        let rows = ArmyCSV.exportRows([army], overrides: [])
        #expect(rows.count == 2)
        #expect(rows[0] == CSVSchema.armyExportHeaders)
        let row = rows[1]
        #expect(row[0] == "40k")
        #expect(row[2] == "GK")
        #expect(row[4] == "2")
        #expect(row[7] == "Yes")
        #expect(row[8] == "#wip")
        #expect(row[12] == "MINE")
        #expect(row[13] == "#112233")
    }

    @Test("exports one row per squad member when tracking is enabled")
    func memberRows() throws {
        let db = TestDatabase()
        let ctx = db.context
        let army = Army(name: "A", game: "40k", faction: "Space Marines"); ctx.insert(army)
        let u = Unit(name: "Intercessors (2)", qty: 1, state: "Primed", order: 0)
        u.army = army; ctx.insert(u)
        SquadStore.enable(u, in: ctx)
        u.member(at: 0)?.state = "Done"
        u.member(at: 0)?.notes = "leader"
        try ctx.save()

        let rows = ArmyCSV.exportRows([army], overrides: [])
        #expect(rows.count == 3)   // header + 2 members
        #expect(rows[1][9] == "1")
        #expect(rows[1][10] == "Done")
        #expect(rows[1][11] == "leader")
        #expect(rows[2][9] == "2")
        #expect(rows[2][10] == "")
    }

    @Test("army CSV round-trips through import")
    func roundTrip() throws {
        let db = TestDatabase()
        let ctx = db.context
        let army = Army(name: "W", game: "40k", faction: "Orks", sortIndex: 0); ctx.insert(army)
        let u = Unit(name: "Boyz (10)", qty: 1, source: "Box", state: "Assembled", order: 0)
        u.army = army; ctx.insert(u)
        try ctx.save()

        let cfg = Config.current(ctx)
        let text = CSV.serialize(ArmyCSV.exportRows([army], overrides: cfg.factionOverrides))
        let imported = ArmyCSV.import(CSV.parse(text), pipeline: DefaultPipeline.stages, overrides: [])
        #expect(imported.ok)
        #expect(imported.armies?.count == 1)
        #expect(imported.armies?.first?.units.first?.name == "Boyz (10)")
        #expect(imported.armies?.first?.units.first?.state == "Assembled")
    }
}

@Suite("Paint CSV export", .serialized)
@MainActor
struct PaintExportTests {
    @Test("exports paints sorted by name")
    func sortedExport() throws {
        let db = TestDatabase()
        let ctx = db.context
        for name in ["Zebra Brown", "Abaddon Black"] {
            let p = Paint(name: name, type: "Base", qty: 2, notes: "note"); ctx.insert(p)
        }
        try ctx.save()
        let paints = try ctx.fetch(FetchDescriptor<Paint>())
        let rows = PaintCSV.exportRows(paints)
        #expect(rows.count == 3)
        #expect(rows[1][0] == "Abaddon Black")
        #expect(rows[2][0] == "Zebra Brown")
        #expect(rows[1][4] == "2")
    }

    @Test("paint CSV round-trips through import")
    func roundTrip() {
        let rows = PaintCSV.exportRows([
            Paint(name: "Khorne Red", type: "Base", qty: 3, brand: "Citadel", source: "Set", notes: "fav"),
        ])
        let text = CSV.serialize(rows)
        let imported = PaintCSV.import(CSV.parse(text))
        #expect(imported.ok)
        #expect(imported.paints?.first?.name == "Khorne Red")
        #expect(imported.paints?.first?.qty == 3)
    }
}
