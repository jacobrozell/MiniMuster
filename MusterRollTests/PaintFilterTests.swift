import Testing
import SwiftData
@testable import MusterRoll

@Suite("PaintFilter", .serialized)
@MainActor
struct PaintFilterTests {
    func samplePaints(in ctx: ModelContext) -> [Paint] {
        [
            Paint(name: "Abaddon Black", type: "Base", brand: "Citadel", source: "Starter", notes: "", low: false),
            Paint(name: "Khorne Red", type: "Base", brand: "Citadel", source: "Set A", notes: "fav", low: true),
            Paint(name: "Contrast Medium", type: "Contrast", brand: "Citadel", source: "", notes: "", low: false),
        ].map { paint in
            ctx.insert(paint)
            return paint
        }
    }

    @Test("type, brand, and low filters combine")
    func filters() {
        let db = TestDatabase()
        let ctx = db.context
        let paints = samplePaints(in: ctx)
        let cfg = Config.current(ctx)

        cfg.paintTypeFilter = "Base"
        #expect(PaintFilter.filter(paints, cfg: cfg, search: "").map(\.name) == ["Abaddon Black", "Khorne Red"])

        PaintFilter.clearFilters(cfg)
        cfg.paintBrandFilter = "Citadel"
        cfg.paintLowOnly = true
        #expect(PaintFilter.filter(paints, cfg: cfg, search: "").map(\.name) == ["Khorne Red"])
    }

    @Test("search matches name, brand, source, and notes")
    func search() {
        let db = TestDatabase()
        let ctx = db.context
        let paints = samplePaints(in: ctx)
        let cfg = Config.current(ctx)

        #expect(PaintFilter.filter(paints, cfg: cfg, search: "starter").map(\.name) == ["Abaddon Black"])
        #expect(PaintFilter.filter(paints, cfg: cfg, search: "fav").map(\.name) == ["Khorne Red"])
        #expect(PaintFilter.filter(paints, cfg: cfg, search: "contrast").map(\.name) == ["Contrast Medium"])
    }

    @Test("active state and counts ignore search text")
    func active() {
        let db = TestDatabase()
        let cfg = Config.current(db.context)
        #expect(!PaintFilter.isActive(cfg, search: ""))
        #expect(PaintFilter.isActive(cfg, search: "red"))
        cfg.paintTypeFilter = "Base"
        #expect(PaintFilter.activeFilterCount(cfg) == 1)
        PaintFilter.clearFilters(cfg)
        #expect(PaintFilter.activeFilterCount(cfg) == 0)
    }
}
