import SwiftUI

/// Colour tokens ported from `css/tokens.css`. Each token resolves per colour scheme.
/// (Full design-system guidance: `docs/ios-spec/10-design-system.md`.)
enum Tokens {
    struct Palette {
        let bg, bg2, surface, surface2, line, ink, inkDim, inkFaint: String
        let gold, goldBright, blood, crestText, chipOnText, err: String
    }

    static let dark = Palette(
        bg: "#0b0c0f", bg2: "#101218", surface: "#15171e", surface2: "#1b1e27",
        line: "#2a2d38", ink: "#e8e5dc", inkDim: "#9a978c", inkFaint: "#65636b",
        gold: "#c9a44c", goldBright: "#e6c878", blood: "#8c2b22",
        crestText: "#0b0c0f", chipOnText: "#1a1407", err: "#f87171")

    static let light = Palette(
        bg: "#f4f1ea", bg2: "#ebe6dc", surface: "#fffdf8", surface2: "#f0ebe3",
        line: "#d4cfc4", ink: "#1a1814", inkDim: "#5c574e", inkFaint: "#8a8478",
        gold: "#9a7428", goldBright: "#7a5a18", blood: "#a83228",
        crestText: "#fffdf8", chipOnText: "#fffdf8", err: "#dc2626")

    static func palette(for scheme: ColorScheme) -> Palette {
        scheme == .dark ? dark : light
    }
}

extension EnvironmentValues {
    /// Convenience accessor for the active palette.
    var palette: Tokens.Palette {
        Tokens.palette(for: colorScheme)
    }
}
