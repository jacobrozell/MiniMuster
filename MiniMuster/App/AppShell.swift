import SwiftUI

/// Root shell: branded splash → main app content.
struct AppShell: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSplash = !AppInfo.isUITesting

    private var screenshotColorScheme: ColorScheme? {
        if ProcessInfo.processInfo.arguments.contains("UI-Testing-DarkTheme") { return .dark }
        if ProcessInfo.processInfo.arguments.contains("UI-Testing-LightTheme") { return .light }
        return nil
    }

    var body: some View {
        ZStack {
            rootContent

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

    @ViewBuilder
    private var rootContent: some View {
        if ProcessInfo.processInfo.arguments.contains("UI-Testing-Accessibility") {
            RootView()
                .environment(\.dynamicTypeSize, .accessibility5)
        } else {
            RootView()
        }
    }
}

#Preview {
    AppShell()
        .modelContainer(AppContainer.previewContainer())
        .environment(BannerCenter())
        .environment(UndoService.shared)
}
