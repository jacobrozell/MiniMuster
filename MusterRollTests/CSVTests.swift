import Testing
@testable import MusterRoll

@Suite("CSV parser")
struct CSVTests {
    @Test("splits simple rows and drops blank lines")
    func simple() {
        let rows = CSV.parse("a,b,c\n1,2,3\n\n4,5,6\n")
        #expect(rows == [["a", "b", "c"], ["1", "2", "3"], ["4", "5", "6"]])
    }

    @Test("handles quoted fields with commas and doubled quotes")
    func quoting() {
        let rows = CSV.parse("name,note\n\"Smith, John\",\"He said \"\"hi\"\"\"\n")
        #expect(rows == [["name", "note"], ["Smith, John", "He said \"hi\""]])
    }

    @Test("handles embedded newline inside quotes")
    func embeddedNewline() {
        let rows = CSV.parse("a,b\n\"line1\nline2\",x\n")
        #expect(rows == [["a", "b"], ["line1\nline2", "x"]])
    }

    @Test("strips BOM and CRLF")
    func bomCRLF() {
        let rows = CSV.parse("\u{FEFF}a,b\r\n1,2\r\n")
        #expect(rows == [["a", "b"], ["1", "2"]])
    }

    @Test("auto-detects tab and semicolon delimiters")
    func delimiters() {
        #expect(CSV.parse("a\tb\n1\t2").first == ["a", "b"])
        #expect(CSV.parse("a;b\n1;2").first == ["a", "b"])
    }

    @Test("serialize round-trips quoting")
    func roundTrip() {
        let rows = [["a", "b,c"], ["d\"e", "f"]]
        let text = CSV.serialize(rows)
        #expect(CSV.parse(text) == rows)
    }
}

@Suite("Field normalizers")
struct NormalizeTests {
    @Test("qty edge cases")
    func qty() {
        #expect(Normalize.qty("").qty == 1)
        #expect(Normalize.qty("5").qty == 5)
        let zero = Normalize.qty("0")
        #expect(zero.qty == 1 && zero.warning != nil)
        let bad = Normalize.qty("x")
        #expect(bad.qty == 1 && bad.warning != nil)
    }

    @Test("bool parsing")
    func bool() {
        #expect(Normalize.bool("yes").value == true)
        #expect(Normalize.bool("0").value == false)
        #expect(Normalize.bool("").value == nil)
        #expect(Normalize.bool("maybe").warning != nil)
    }
}

@Suite("CSV schema")
struct CSVSchemaTests {
    @Test("detects armies vs paints from headers")
    func detect() {
        #expect(CSVSchema.detect([["Game", "Army", "Unit"]]) == .armies)
        #expect(CSVSchema.detect([["Name", "Type"]]) == .paints)
        #expect(CSVSchema.detect([["Foo", "Bar"]]) == nil)
    }

    @Test("templates and filenames match web conventions")
    func templates() {
        #expect(CSVSchema.template(.armies).contains("Game,Faction,Army"))
        #expect(CSVSchema.template(.paints).contains("Name,Type"))
        #expect(CSVSchema.filename(.armies) == "warhammer_armies.csv")
        #expect(CSVSchema.filename(.paints) == "warhammer_paint_inventory.csv")
    }

    @Test("templates include required import columns")
    func requiredColumns() {
        let armyRows = CSV.parse(CSVSchema.template(.armies))
        let armyMap = HeaderMap(rows: armyRows, required: CSVSchema.armyRequired)
        #expect(armyMap.ok)

        let paintRows = CSV.parse(CSVSchema.template(.paints))
        let paintMap = HeaderMap(rows: paintRows, required: CSVSchema.paintRequired)
        #expect(paintMap.ok)
    }

    @Test("templates parse as header plus one example row")
    func rowCount() {
        #expect(CSV.parse(CSVSchema.template(.armies)).count == 2)
        #expect(CSV.parse(CSVSchema.template(.paints)).count == 2)
    }

    @Test("templates are auto-detected by domain")
    func detectTemplates() {
        #expect(CSVSchema.detect(CSV.parse(CSVSchema.template(.armies))) == .armies)
        #expect(CSVSchema.detect(CSV.parse(CSVSchema.template(.paints))) == .paints)
    }

    @Test("armies template example row imports successfully")
    func armiesTemplateImports() {
        let rows = CSV.parse(CSVSchema.template(.armies))
        let result = ArmyCSV.import(rows, pipeline: DefaultPipeline.stages, overrides: [])
        #expect(result.ok)
        #expect(result.stats["armies"] == 1)
        #expect(result.stats["units"] == 1)
        #expect(result.armies?.first?.name == "My Chapter")
        #expect(result.armies?.first?.units.first?.name == "Intercessors (5)")
    }

    @Test("paints template example row imports successfully")
    func paintsTemplateImports() {
        let rows = CSV.parse(CSVSchema.template(.paints))
        let result = PaintCSV.import(rows)
        #expect(result.ok)
        #expect(result.stats["paints"] == 1)
        #expect(result.paints?.first?.name == "Macragge Blue")
        #expect(result.paints?.first?.type == "Base")
    }
}

@Suite("HeaderMap")
struct HeaderMapTests {
    @Test("empty file fails with a clear error")
    func empty() {
        let hm = HeaderMap(rows: [], required: CSVSchema.armyRequired)
        #expect(!hm.ok)
        #expect(hm.error == "File is empty")
    }

    @Test("value lookup is case-insensitive on headers")
    func lookup() {
        let hm = HeaderMap(rows: [["Game", "Faction", "Army", "Unit", "Qty"]], required: CSVSchema.armyRequired)
        #expect(hm.ok)
        #expect(hm.value(["40k", "Orks", "W", "Boyz", "2"], "army") == "W")
        #expect(hm.value(["40k", "W", "Boyz"], "qty") == "")
    }
}

@Suite("Import hints")
struct ImportHintTests {
    @Test("rejects Excel extensions with guidance")
    func excel() {
        #expect(fileImportHint("roster.xlsx")?.contains("Excel") == true)
        #expect(fileImportHint("roster.xls")?.contains("CSV") == true)
        #expect(fileImportHint("roster.csv") == nil)
    }
}
