import SwiftUI

/// Root shell: branded splash → main app content.
struct AppShell: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSplash = !AppInfo.isUITesting

    var body: some View {
        ZStack {
            RootView()

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task(id: showSplash) {
            guard showSplash else { return }
            try? await Task.sleep(for: .milliseconds(850))
            if reduceMotion {
                showSplash = false
            } else {
                withAnimation(.easeOut(duration: 0.35)) {
                    showSplash = false
                }
            }
        }
    }
}

#Preview {
    AppShell()
        .modelContainer(AppContainer.previewContainer())
        .environment(BannerCenter())
        .environment(UndoService.shared)
}
