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
