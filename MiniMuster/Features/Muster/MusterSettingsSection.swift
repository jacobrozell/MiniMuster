import SwiftUI
import SwiftData

struct MusterIntroSheet: View {
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text("Muster for the table")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    Text("Build point lists in the Muster tab. See which units you already own in Collection and send missing models straight to your painting army.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                .padding(.top, 32)
                .padding(.bottom, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") { onDismiss() }
                        .accessibilityIdentifier("musterIntroDismiss")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct MusterSettingsSection: View {
    @Environment(\.modelContext) private var context
    @Bindable var cfg: AppConfiguration
    @State private var showDisclaimer = false

    var body: some View {
        Section("Muster") {
            LabeledContent("Catalog version", value: UnitCatalogLoader.version)
            Button("Disclaimer", systemImage: "info.circle") { showDisclaimer = true }
            Picker("Default battle size (40k)", selection: Binding(
                get: { cfg.defaultBattleSizeKey40k },
                set: { cfg.defaultBattleSizeKey40k = $0; try? context.save() }
            )) {
                ForEach(BattleSizes.forGame("40k")) { size in
                    Text(size.label).tag(size.id)
                }
            }
            Button("Reset Muster intro", systemImage: "arrow.counterclockwise") {
                cfg.hasSeenMusterIntro = false
                try? context.save()
            }
        }
        .alert("Unofficial data", isPresented: $showDisclaimer) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Unit names and points values are unofficial community data for personal list building. Not endorsed by Games Workshop. Verify before events.")
        }
    }
}
