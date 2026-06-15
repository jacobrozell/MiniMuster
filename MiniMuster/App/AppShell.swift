import SwiftUI

/// Root shell: branded splash → main app content.
struct AppShell: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSplash = !AppInfo.isUITesting

    private var screenshotColorScheme: ColorScheme? {
        ProcessInfo.processInfo.arguments.contains("UI-Testing-DarkTheme") ? .dark : nil
    }

    var body: some View {
        ZStack {
            RootView()

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(screenshotColorScheme)
        .task(id: showSplash) {
            guard showSplash else { return }
            // Brief branded moment so the loader reads as intentional, not a flash.
            try? await Task.sleep(for: .milliseconds(AppInfo.isUITesting ? 0 : 1_400))
            if reduceMotion {
                showSplash = false
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
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
