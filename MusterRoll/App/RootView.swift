import SwiftUI
import SwiftData

/// Two-tab shell: Armies / Paint Rack. Mirrors the web `.tabs` and theme application.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toast
    @Query private var armies: [Army]
    @Query private var paints: [Paint]
    @Query private var configs: [AppConfiguration]

    @State private var router = AppRouter()
    @State private var checkedBackup = false

    private var theme: ThemePreference { configs.first?.theme ?? .system }
    private var unitCount: Int { armies.reduce(0) { $0 + $1.units.count } }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab(value: AppRouter.Tab.armies) {
                NavigationStack { ArmiesScreen() }
            } label: {
                Label("Armies", systemImage: "shield.lefthalf.filled")
            }
            .badge(unitCount)

            Tab(value: AppRouter.Tab.paints) {
                NavigationStack { PaintRackScreen() }
            } label: {
                Label("Paint Rack", systemImage: "paintpalette")
            }
            .badge(paints.count)
        }
        .environment(router)
        .tint(Color(hex: "#c9a44c"))
        .preferredColorScheme(theme.colorScheme)
        .onAppear {
            AppContainer.ensureConfiguration(context)
            checkBackupReminder()
        }
    }

    /// Nudge to back up if there's data and no Full backup in 14+ days. Mirrors
    /// `js/ui/backup-reminder.js` (once per launch).
    private func checkBackupReminder() {
        guard !checkedBackup else { return }
        checkedBackup = true
        guard !armies.isEmpty || !paints.isEmpty else { return }
        let days = configs.first?.lastBackupAt.map { Date().timeIntervalSince($0) / 86400 } ?? .infinity
        if days >= 14 {
            toast.show("Tip: export a Full backup — CSV exports don't include pipeline or theme", duration: 6)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(AppContainer.previewContainer())
        .environment(ToastCenter())
        .environment(UndoService.shared)
}
