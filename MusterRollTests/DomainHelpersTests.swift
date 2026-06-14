import Testing
@testable import MusterRoll

@Suite("Tags")
struct TagsTests {
    @Test("extracts lowercased #tags without the hash")
    func extract() {
        #expect(Tags.extract("needs #repaint and #kitbash-2") == ["repaint", "kitbash-2"])
        #expect(Tags.extract("no tags here").isEmpty)
        #expect(Tags.extract("#ALPHA") == ["alpha"])
    }
}

@Suite("SourceMatch")
struct SourceMatchTests {
    @Test("fuzzy matches across + groups, both directions")
    func matches() {
        #expect(SourceMatch.matches("Skaven Kit + Stormcast Kit", "Stormcast Kit"))
        #expect(SourceMatch.matches("Skaventide", "Skaventide"))
        #expect(SourceMatch.matches("Skaven", "Skaven Painting Kit"))   // part inside unit
        #expect(!SourceMatch.matches("Skaventide", ""))
        #expect(!SourceMatch.matches("Combat Patrol", "Spearhead"))
    }
}

@Suite("FactionResolver")
struct FactionResolverTests {
    @Test("normalizes aliases to canonical labels")
    func aliases() {
        #expect(FactionResolver.normalize("Sisters of Battle") == "Adepta Sororitas")
        #expect(FactionResolver.normalize("Eldar") == "Aeldari")
        #expect(FactionResolver.normalize("Heretic Astartes: Death Guard") == "Death Guard")
    }

    @Test("composite resolution by game")
    func composite() {
        let r = FactionResolver.resolve(faction: "Grey Knights", game: "40k", overrides: [])
        #expect(r.crest == "GK")
        #expect(r.color == "#aeb6bd")
    }

    @Test("unknown faction falls back to 2-char crest and grey")
    func fallback() {
        let r = FactionResolver.resolve(faction: "Squats", game: "40k", overrides: [])
        #expect(r.crest == "SQ")
        #expect(r.color == "#888")
        #expect(FactionResolver.isFallback(r.color))
    }

    @Test("user override beats the catalogue")
    func override() {
        let o = [FactionPresetOverride(key: "40k:Grey Knights", crest: "MINE", hex: "#123456")]
        let r = FactionResolver.resolve(faction: "Grey Knights", game: "40k", overrides: o)
        #expect(r.crest == "MINE")
        #expect(r.color == "#123456")
    }
}

@Suite("FactionCatalogue integrity")
struct FactionCatalogueTests {
    @Test("every def has a valid crest, colour, and games")
    func integrity() {
        for d in FactionDefs.all {
            #expect(!d.label.isEmpty)
            #expect(!d.crest.isEmpty && d.crest.count <= 8)
            #expect(safeColor(d.color) == d.color, "invalid hex for \(d.label): \(d.color)")
            #expect(!d.games.isEmpty)
        }
    }

    @Test("composite keys are unique")
    func uniqueComposites() {
        var seen = Set<String>()
        for d in FactionDefs.all {
            for g in d.games {
                let key = FactionResolver.compositeKey(game: g, faction: d.label)
                #expect(seen.insert(key).inserted, "duplicate composite key: \(key)")
            }
        }
    }
}
