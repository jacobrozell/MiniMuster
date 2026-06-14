import SwiftUI

extension ThemePreference {
    /// SwiftUI colour-scheme override. `system` → nil (follow the device).
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}
