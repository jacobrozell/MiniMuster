import SwiftUI

/// Brief inline banner below the navigation bar (replaces toast overlay).
@Observable
@MainActor
final class BannerCenter {
    var message: String?
    private var token = 0

    func show(_ text: String, duration: Double = 3.0) {
        message = text
        token += 1
        let current = token
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if current == token { message = nil }
        }
    }
}

private struct BannerModifier: ViewModifier {
    @Environment(BannerCenter.self) private var banner
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            if let message = banner.message {
                Text(message)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                    .overlay(alignment: .bottom) { Divider() }
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: banner.message)
    }
}

extension View {
    func bannerInset() -> some View { modifier(BannerModifier()) }
}
