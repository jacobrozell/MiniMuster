import Testing
@testable import MusterRoll

@Suite("Army CSV import")
struct ArmyImportTests {
    let pipeline = DefaultPipeline.stages

    @Test("groups rows by army, taking game/faction from the first row")
    func grouping() {
        let csv = """
        Game,Faction,Army,Unit,Qty,Source,State,Spearhead,Notes
        AoS,Skaven,Vermindoom,Clanrats (5),2,Skaventide,Based,Yes,
        AoS,Skaven,Vermindoom,Rat Ogors,3,Skaventide,Assembled,No,
        40k,Grey Knights,GK,Strike Squad (5),1,Combat Patrol,Primed,,note
        """
        let r = ArmyCSV.import(CSV.parse(csv), pipeline: pipeline, overrides: [])
        #expect(r.ok)
        #expect(r.stats["armies"] == 2)
        #expect(r.stats["units"] == 3)
        let vermin = r.armies?.first { $0.name == "Vermindoom" }
        #expect(vermin?.faction == "Skaven")
        #expect(vermin?.units.count == 2)
        #expect(vermin?.units.first?.qty == 2)
        #expect(vermin?.units.first?.spearhead == true)
    }

    @Test("normalizes unknown state with a warning")
    func unknownState() {
        let csv = "Game,Faction,Army,Unit,State\n40k,Orks,WAAAGH,Boyz (10),Glazed\n"
        let r = ArmyCSV.import(CSV.parse(csv), pipeline: pipeline, overrides: [])
        #expect(r.armies?.first?.units.first?.state == "Unassembled")
        #expect(r.warnings.contains { $0.contains("Unknown state") })
    }

    @Test("warns once for an unknown faction")
    func unknownFaction() {
        let csv = "Game,Faction,Army,Unit\n40k,Squats,Hold,Warrior (5)\n40k,Squats,Hold,Biker\n"
        let r = ArmyCSV.import(CSV.parse(csv), pipeline: pipeline, overrides: [])
        #expect(r.warnings.filter { $0.contains("Unknown faction") }.count == 1)
    }

    @Test("captures crest/colour overrides and flags invalid colour")
    func crestColor() {
        let csv = """
        Game,Faction,Army,Unit,Crest,Color
        40k,Space Marines,Mine,Tac (10),MINE,#123456
        40k,Space Marines,Bad,Tac (10),BAD,notacolor
        """
        let r = ArmyCSV.import(CSV.parse(csv), pipeline: pipeline, overrides: [])
        let mine = r.armies?.first { $0.name == "Mine" }
        #expect(mine?.crestOverride == "MINE")
        #expect(mine?.colorOverrideHex == "#123456")
        #expect(r.warnings.contains { $0.contains("invalid Color") })
    }

    @Test("assigns squad members and merges member rows by group key")
    func members() {
        let csv = """
        Game,Faction,Army,Unit,Qty,Source,State,Member,MemberState,MemberNotes
        40k,Space Marines,M,Intercessors (5),1,Box,Primed,1,Done,test recipe
        40k,Space Marines,M,Intercessors (5),1,Box,Primed,2,Based,
        """
        let r = ArmyCSV.import(CSV.parse(csv), pipeline: pipeline, overrides: [])
        let unit = r.armies?.first?.units.first
        #expect(r.armies?.first?.units.count == 1)   // both member rows merged into one unit
        #expect(unit?.members.count == 5)
        #expect(unit?.members[0].state == "Done")
        #expect(unit?.members[0].notes == "test recipe")
        #expect(unit?.members[1].state == "Based")
        #expect(unit?.members[2].state == nil)       // inherits
    }

    @Test("warns when a member exceeds squad size")
    func memberOverflow() {
        let csv = "Game,Faction,Army,Unit,Member\n40k,Orks,W,Nob (1),3\n"
        let r = ArmyCSV.import(CSV.parse(csv), pipeline: pipeline, overrides: [])
        #expect(r.warnings.contains { $0.contains("exceeds squad size") })
    }

    @Test("errors on missing required column")
    func missingColumn() {
        let r = ArmyCSV.import(CSV.parse("Game,Faction,Army\n40k,Orks,W\n"), pipeline: pipeline, overrides: [])
        #expect(!r.ok)
        #expect(r.errors.first?.contains("Missing required columns") == true)
    }
}

@Suite("Paint CSV import")
struct PaintImportTests {
    @Test("imports and merges duplicate names")
    func merge() {
        let csv = """
        Name,Type,Brand,Source,Quantity,Notes
        Leadbelcher,Base,Citadel,Kit A,1,
        Leadbelcher,Base,Citadel,Kit B,2,from both
        Khorne Red,Base,Citadel,Kit A,1,
        """
        let r = PaintCSV.import(CSV.parse(csv))
        #expect(r.ok)
        #expect(r.stats["paints"] == 2)
        let lead = r.paints?.first { $0.name == "Leadbelcher" }
        #expect(lead?.qty == 3)
        #expect(lead?.notes == "from both")
        #expect(r.warnings.contains { $0.contains("Merged duplicate") })
    }

    @Test("derives swatch from type and skips blank names")
    func swatchAndBlank() {
        let csv = "Name,Type\nCorax White,Base\n,\n"
        let r = PaintCSV.import(CSV.parse(csv))
        #expect(r.paints?.count == 1)
        #expect(r.paints?.first?.swatchHex == PaintType.swatchHex(for: "Base"))
    }
}
