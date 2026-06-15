import Testing
import SwiftData
import SwiftUI
@testable import MiniMuster

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

    @Test("parts splits on plus and normalizes")
    func parts() {
        #expect(SourceMatch.parts("  Foo + Bar  ") == ["foo", "bar"])
        #expect(SourceMatch.parts("solo") == ["solo"])
        #expect(SourceMatch.parts("++").isEmpty)
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

    @Test("compositeKey and flat resolution without game")
    func compositeAndFlat() {
        #expect(FactionResolver.compositeKey(game: "40k", faction: "Orks") == "40k:Orks")
        #expect(FactionResolver.compositeKey(game: "", faction: "Orks") == "Orks")
        let flat = FactionResolver.resolve(faction: "Grey Knights", game: "", overrides: [])
        #expect(flat.crest == "GK")
    }
}

@Suite("safeColor")
struct SafeColorTests {
    @Test("accepts valid hex and rejects unsafe values")
    func hex() {
        #expect(safeColor("#abc") == "#abc")
        #expect(safeColor("#AABBCC") == "#AABBCC")
        #expect(safeColor("javascript:alert(1)") == "#888")
        #expect(safeColor(nil) == "#888")
    }
}

@Suite("Limits")
struct LimitsTests {
    @Test("capped trims and clamps string length")
    func capped() {
        #expect("  hello  ".capped(3) == "hel")
        #expect("x".capped(10) == "x")
    }
}

@Suite("PaintType")
struct PaintTypeTests {
    @Test("known types map to default swatches")
    func swatches() {
        #expect(PaintType.swatchHex(for: "Base") == "#7a7a7a")
        #expect(PaintType.swatchHex(for: "Unknown") == "#777")
        #expect(PaintType.known.contains("Primer"))
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

@Suite("Color hex parsing")
struct ColorHexTests {
    @Test("parses shorthand and full hex strings")
    func initHex() {
        #expect(Color(hex: "#abc").hexString.lowercased() == "#aabbcc")
        #expect(Color(hex: "#112233").hexString.lowercased() == "#112233")
        #expect(Color(hex: "javascript:alert(1)").hexString.lowercased() == "#888888")
    }
}

@Suite("ThemePreference")
struct ThemePreferenceTests {
    @Test("cycles dark → light → system")
    func cycle() {
        #expect(ThemePreference.dark.next == .light)
        #expect(ThemePreference.light.next == .system)
        #expect(ThemePreference.system.next == .dark)
    }

    @Test("AppConfiguration theme round-trips")
    @MainActor
    func configTheme() {
        let db = TestDatabase()
        let cfg = Config.current(db.context)
        cfg.theme = .dark
        #expect(cfg.themeRaw == ThemePreference.dark.rawValue)
        #expect(cfg.theme == .dark)
    }
}
