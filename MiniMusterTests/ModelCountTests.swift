import Testing
@testable import MiniMuster

@Suite("ModelCount")
struct ModelCountTests {
    @Test("parentheses maths", arguments: [
        ("Intercessors (5)", 1, 5),
        ("Clanrats (5)", 2, 10),
        ("Reclusians + Memorians (x3 + x2)", 1, 5),
        ("Lord-Vigilant", 1, 1),
        ("Lord-Vigilant", 3, 3),
        ("Squad ()", 2, 2),
        ("Box (10) spare (2)", 1, 10),
    ])
    func count(name: String, qty: Int, expected: Int) {
        #expect(ModelCount.of(name: name, qty: qty) == expected)
    }

    @Test("qty is clamped to at least 1")
    func clamp() {
        #expect(ModelCount.of(name: "Thing", qty: 0) == 1)
        #expect(ModelCount.of(name: "Thing (3)", qty: 0) == 3)
    }

    @Test("unclosed parenthesis falls back to qty")
    func unclosedParen() {
        #expect(ModelCount.firstParenGroup("Squad (5") == nil)
        #expect(ModelCount.of(name: "Squad (5", qty: 2) == 2)
    }
}
