import SwiftUI

/// Transient bottom banner messages. Mirrors `js/ui/toast.js`. Injected at the root and
/// shown via `.toastOverlay()`.
@Observable
@MainActor
final class ToastCenter {
    var message: String?
    private var token = 0

    func show(_ text: String, duration: Double = 2.0) {
        message = text
        token += 1
        let current = token
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if current == token { message = nil }
        }
    }
}

private struct ToastOverlay: ViewModifier {
    @Environment(ToastCenter.self) private var toast

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message = toast.message {
                Text(message)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color(hex: "#c9a44c").opacity(0.4)))
                    .padding(.bottom, 24)
                    .shadow(radius: 8, y: 2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.spring(duration: 0.3), value: toast.message)
    }
}

extension View {
    func toastOverlay() -> some View { modifier(ToastOverlay()) }
}
