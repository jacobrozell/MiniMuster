import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(BannerCenter.self) private var banner
    @Query private var armies: [Army]
    @Query private var paints: [Paint]
    @Query private var configs: [AppConfiguration]

    @State private var router = AppRouter()
    @State private var checkedBackup = false
    @State private var showBackupReminder = false
    @State private var showOnboarding = false
    @State private var showSettings = false
    @AppStorage("backupReminderSnoozedUntil") private var backupReminderSnoozedUntil = 0.0

    private var theme: ThemePreference { configs.first?.theme ?? .system }
    private var unitCount: Int { armies.reduce(0) { $0 + $1.units.count } }

    /// Changes when sprue/total model counts change, not only army or unit row counts.
    private var widgetSignature: Int {
        let pipeline = Pipeline.resolve(configs.first?.globalPipeline)
        let first = pipeline.first?.key ?? "Unassembled"
        let units = armies.flatMap(\.units)
        let sprue = units.filter { $0.state == first }.reduce(0) { $0 + $1.modelCount }
        let total = units.reduce(0) { $0 + $1.modelCount }
        var hasher = Hasher()
        hasher.combine(sprue)
        hasher.combine(total)
        hasher.combine(armies.count)
        hasher.combine(paints.count)
        return hasher.finalize()
    }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab(value: AppRouter.Tab.armies) {
                CollectionTab()
            } label: {
                Label("Collection", systemImage: "shield.lefthalf.filled")
                    .accessibilityIdentifier("tabCollection")
            }
            .badge(unitCount)

            Tab(value: AppRouter.Tab.paints) {
                PaintsTab()
            } label: {
                Label("Paints", systemImage: "paintpalette.fill")
                    .accessibilityIdentifier("tabPaints")
            }
            .badge(paints.count)
        }
        .environment(router)
        .tint(.accentColor)
        .preferredColorScheme(theme.colorScheme)
        .bannerInset()
        .onAppear {
            AppContainer.ensureConfiguration(context)
            seedUITestDataIfNeeded()
            checkOnboarding()
            checkBackupReminder()
            refreshWidget()
        }
        .onChange(of: armies.count) { checkOnboarding() }
        .onChange(of: paints.count) { checkOnboarding() }
        .onChange(of: widgetSignature) { refreshWidget() }
        .onOpenURL { url in
            if let destination = AppDeepLink.destination(from: url) {
                router.open(destination)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { completeOnboarding($0) }
        }
        .sheet(isPresented: $showSettings) { SettingsScreen() }
        .alert("Backup reminder", isPresented: $showBackupReminder) {
            Button("Open Settings") { showSettings = true }
            Button("Remind Me Later") {
                backupReminderSnoozedUntil = Date().addingTimeInterval(7 * 86400).timeIntervalSince1970
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("It's been 14+ days since your last full backup. Export one from Settings → Data.")
        }
    }

    private func seedUITestDataIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("UI-Testing-Seeded") else { return }
        guard armies.isEmpty, paints.isEmpty else { return }
        _ = try? DemoLoader.load(into: context)
        if let cfg = configs.first {
            cfg.hasSeenOnboarding = true
            try? context.save()
        }
    }

    private func checkOnboarding() {
        guard let cfg = configs.first else { return }
        guard !cfg.hasSeenOnboarding else { return }
        if !armies.isEmpty || !paints.isEmpty {
            cfg.hasSeenOnboarding = true
            try? context.save()
            return
        }
        guard !showOnboarding else { return }
        showOnboarding = true
    }

    private func completeOnboarding(_ action: OnboardingView.Completion) {
        let cfg = Config.current(context)
        cfg.hasSeenOnboarding = true
        try? context.save()
        showOnboarding = false
        switch action {
        case .dismiss: break
        case .loadSample: banner.show(DataActions.loadSample(ctx: context))
        case .openSettings: showSettings = true
        }
    }

    private func checkBackupReminder() {
        guard !checkedBackup else { return }
        checkedBackup = true
        guard !AppInfo.isUITesting else { return }
        guard !armies.isEmpty || !paints.isEmpty else { return }
        guard Date().timeIntervalSince1970 >= backupReminderSnoozedUntil else { return }
        guard let lastBackup = configs.first?.lastBackupAt else { return }
        let days = Date().timeIntervalSince(lastBackup) / 86400
        if days >= 14 { showBackupReminder = true }
    }

    private func refreshWidget() {
        WidgetUpdater.refresh(armies: armies, globalPipeline: configs.first?.globalPipeline)
    }
}

#Preview {
    RootView()
        .modelContainer(AppContainer.previewContainer())
        .environment(BannerCenter())
        .environment(UndoService.shared)
        .environment(AppRouter())
}
