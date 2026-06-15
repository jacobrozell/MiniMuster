import SwiftUI

/// Shared size-class and Dynamic Type helpers for adaptive navigation and list chrome.
enum AdaptiveLayout {
    /// Two-column split (sidebar + detail) when horizontal space is regular — iPad full screen, not iPhone or iPad slide-over.
    static func usesSplitNavigation(_ horizontal: UserInterfaceSizeClass?) -> Bool {
        horizontal == .regular
    }

    /// Sidebar-style list chrome inside a split column.
    static func usesSidebarListStyle(_ horizontal: UserInterfaceSizeClass?) -> Bool {
        horizontal == .regular
    }

    /// Wider split column when Dynamic Type is in an accessibility bucket.
    static func splitColumnWidth(dynamicType: DynamicTypeSize) -> (min: CGFloat, ideal: CGFloat, max: CGFloat) {
        if dynamicType.isAccessibilitySize {
            (380, 420, 520)
        } else {
            (320, 380, 440)
        }
    }
}

extension View {
    /// Sidebar selection tint for split-view lists; omit on iPhone where `NavigationLink` handles navigation.
    @ViewBuilder
    func listSidebarSelection(isSelected: Bool, enabled: Bool) -> some View {
        if enabled, isSelected {
            listRowBackground(Color.accentColor.opacity(0.12))
        } else {
            self
        }
    }
}
