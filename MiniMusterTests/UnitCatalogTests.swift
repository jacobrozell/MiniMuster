import Foundation
import SwiftData
import Testing
@testable import MiniMuster

@Suite("UnitCatalog")
struct UnitCatalogTests {
    @Test("loads grey knights catalog from bundle")
    func loadGK() {
        UnitCatalogLoader.loadIfNeeded()
        let units = UnitCatalogLoader.units(game: "40k", faction: "Grey Knights")
        #expect(units.count >= 5)
        #expect(units.contains { $0.id.contains("interceptor") })
    }

    @Test("search finds aliases")
    func searchAlias() {
        UnitCatalogLoader.loadIfNeeded()
        let hits = UnitCatalogLoader.search(game: "40k", faction: "Grey Knights", query: "Interceptors")
        #expect(hits.contains { $0.name == "Interceptor Squad" })
    }

    @Test("manifest version is present")
    func version() {
        UnitCatalogLoader.loadIfNeeded()
        #expect(UnitCatalogLoader.version != "0")
    }
}
