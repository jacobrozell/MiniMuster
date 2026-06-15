import Foundation
import Testing
@testable import MiniMuster

@Suite("UnitNameMatch")
struct UnitNameMatchTests {
    @Test("Interceptor Squad matches Interceptors alias")
    func alias() {
        #expect(UnitNameMatch.matches(collectionUnitName: "Interceptors",
                                      catalogName: "Interceptor Squad",
                                      aliases: ["Interceptors"]))
    }

    @Test("Strike Squad (5) normalizes to strike squad")
    func parenNormalize() {
        let normalized = UnitNameMatch.normalize("Strike Squad (5)")
        #expect(normalized == "strike squad")
        #expect(UnitNameMatch.matches(collectionUnitName: "Strike Squad (5)",
                                      catalogName: "Strike Squad",
                                      aliases: []))
    }
}
