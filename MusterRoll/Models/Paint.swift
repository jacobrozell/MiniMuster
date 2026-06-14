import Foundation
import SwiftData

/// One distinct paint pot / basing product. Mirrors the web `Paint` typedef
/// `{ name, type, swatch, qty, brand, source, notes, low? }`. Uniqueness of `name`
/// (case-insensitive) is enforced in app logic, not via `@Attribute(.unique)`.
@Model
final class Paint {
    var id: UUID = UUID()
    var name: String = ""
    var type: String = ""            // "" or a known type (see PaintType)
    var swatchHex: String = "#777"   // derived from type on create/import; persisted
    var qty: Int = 1                 // clamped 1...9999
    var brand: String = ""
    var source: String = ""
    var notes: String = ""
    var low: Bool = false            // "running low / need more"

    init(name: String,
         type: String = "",
         swatchHex: String = "#777",
         qty: Int = 1,
         brand: String = "",
         source: String = "",
         notes: String = "",
         low: Bool = false) {
        self.name = name
        self.type = type
        self.swatchHex = swatchHex
        self.qty = max(1, qty)
        self.brand = brand
        self.source = source
        self.notes = notes
        self.low = low
    }
}

/// Paint types and their default swatch colours. Ports `DEFAULT_PAINT_TYPES`
/// (`js/core/constants.js`) and the type list from `js/render/paints.js`.
enum PaintType {
    static let known = ["", "Base", "Shade", "Technical", "Speedpaint",
                        "Speedpaint Metallic", "Medium", "Primer", "Basing"]

    static let swatch: [String: String] = [
        "Base": "#7a7a7a",
        "Shade": "#3a2c1c",
        "Technical": "#5a5550",
        "Speedpaint": "#888",
        "Speedpaint Metallic": "#9a9da1",
        "Medium": "#d9d4c8",
        "Primer": "#6b6b6b",
        "Basing": "#6b7a3a",
    ]

    static func swatchHex(for type: String) -> String {
        swatch[type] ?? "#777"
    }
}
