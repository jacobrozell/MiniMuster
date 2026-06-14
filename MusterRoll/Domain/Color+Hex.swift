import SwiftUI

/// Restrict user-supplied colours to safe values. Ports `safeColor` from `js/core/dom.js`:
/// accepts `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA` (3–8 hex digits after `#`), else `#888`.
func safeColor(_ raw: String?) -> String {
    let s = (raw ?? "").trimmingCharacters(in: .whitespaces)
    if s.wholeMatch(of: /#[0-9a-fA-F]{3,8}/) != nil { return s }
    return "#888"
}

extension Color {
    /// `#RRGGBB` string for this colour (for persisting ColorPicker output).
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x",
                      Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    /// Parse a `safeColor`-shaped hex string. Falls back to grey for anything unparseable.
    init(hex raw: String) {
        let s = safeColor(raw)
        var hex = String(s.dropFirst())   // strip leading '#'

        // Expand shorthand #RGB / #RGBA to full byte pairs.
        if hex.count == 3 || hex.count == 4 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }

        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)

        let r, g, b, a: Double
        switch hex.count {
        case 8: // RRGGBBAA
            r = Double((value & 0xFF00_0000) >> 24) / 255
            g = Double((value & 0x00FF_0000) >> 16) / 255
            b = Double((value & 0x0000_FF00) >> 8) / 255
            a = Double(value & 0x0000_00FF) / 255
        default: // RRGGBB (and anything unexpected resolves to grey via safeColor)
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
