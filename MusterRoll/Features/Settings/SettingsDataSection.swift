import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Data import/export controls for Settings.
@MainActor
struct SettingsDataSection: View {
    @Environment(\.modelContext) private var context
    @Environment(BannerCenter.self) private var banner

    @State private var importMode: DataActions.Mode = .replace
    @State private var importDomain: ImportDomain = .armies
    @State private var showCSVImporter = false
    @State private var showJSONImporter = false
    @State private var showExporter = false
    @State private var exportDoc = TextFileDocument(text: "")
    @State private var exportName = "export"
    @State private var exportType: UTType = .commaSeparatedText
    @State private var importOutcome: DataActions.ImportOutcome?
    @State private var alertError: (title: String, message: String)?
    @State private var confirmClear = false
    @State private var confirmRestore = false
    @State private var confirmReplaceImport = false
    @State private var pendingImportURL: URL?
    @State private var importSuccessTrigger = false
    @State private var importErrorTrigger = false

    enum ImportDomain { case armies, paints }

    private var alertPresented: Binding<Bool> {
        Binding(
            get: { alertError != nil },
            set: { if !$0 { alertError = nil } }
        )
    }

    var body: some View {
        formSections
            .fileImporter(isPresented: $showCSVImporter,
                          allowedContentTypes: [.commaSeparatedText, .plainText]) { handleCSV($0) }
            .fileImporter(isPresented: $showJSONImporter, allowedContentTypes: [.json]) { handleJSON($0) }
            .fileExporter(isPresented: $showExporter, document: exportDoc,
                          contentType: exportType, defaultFilename: exportName) { _ in }
            .sheet(item: $importOutcome, content: importResultsSheet)
            .alert(alertError?.title ?? "Error", isPresented: alertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                if let alertError { Text(alertError.message) }
            }
            .confirmationDialog("Replace all data on this device?",
                                isPresented: $confirmRestore, titleVisibility: .visible) {
                Button("Choose backup file") { showJSONImporter = true }
            } message: {
                Text("Restoring a backup replaces armies, paints, and settings.")
            }
            .confirmationDialog("Delete all armies, paints, and settings?",
                                isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear all", role: .destructive) { clearAllData() }
            }
            .confirmationDialog("Replace existing data?",
                                isPresented: $confirmReplaceImport, titleVisibility: .visible) {
                Button("Replace") { runPendingImport() }
                Button("Cancel", role: .cancel) { pendingImportURL = nil }
            } message: {
                Text(replaceImportMessage)
            }
            .sensoryFeedback(.success, trigger: importSuccessTrigger)
            .sensoryFeedback(.error, trigger: importErrorTrigger)
    }

    @ViewBuilder
    private var formSections: some View {
        Section {
            if let cfg = try? context.fetch(FetchDescriptor<AppConfiguration>()).first,
               let last = cfg.lastBackupAt {
                LabeledContent("Last backup") {
                    Text(last, style: .date).foregroundStyle(.secondary)
                }
            }
        }

        templateSection

        Section("Import") {
            Button("Import armies (replace)…") { beginImport(.armies, .replace) }
            Button("Import armies (append)…") { beginImport(.armies, .append) }
            Button("Import paints (replace)…") { beginImport(.paints, .replace) }
            Button("Import paints (append)…") { beginImport(.paints, .append) }
        }

        Section("Export") {
            Button("Export armies CSV") { exportArmiesCSV() }
            Button("Export paints CSV") { exportPaintsCSV() }
            Button("Full backup (JSON)") { exportBackup() }
        }

        Section("Backup & sample") {
            Button("Restore backup…") { confirmRestore = true }
            Button("Load sample collection") {
                presentOutcome(DataActions.loadSampleOutcome(ctx: context))
            }
            Button("Clear all data", role: .destructive) { confirmClear = true }
        }
    }

    private var replaceImportMessage: String {
        let noun = importDomain == .armies ? "armies" : "paints"
        return "Import (replace) will delete current \(noun) before importing."
    }

    @ViewBuilder
    private func importResultsSheet(_ outcome: DataActions.ImportOutcome) -> some View {
        ImportResultsSheet(title: outcome.title, message: outcome.message,
                           warnings: outcome.warnings, failed: false)
            .presentationDetents([.medium, .large])
    }

    private func beginImport(_ domain: ImportDomain, _ mode: DataActions.Mode) {
        importDomain = domain
        importMode = mode
        showCSVImporter = true
    }

    private func clearAllData() {
        CollectionStore.clearAll(in: context)
        WidgetUpdater.refresh(context: context)
        banner.show("All data cleared")
    }

    private var templateSection: some View {
        Section {
            Button("Armies template") { exportArmiesTemplate() }
            Button("Paints template") { exportPaintsTemplate() }
        } header: {
            Text("CSV templates")
        } footer: {
            Text("Download a starter CSV with the correct columns and an example row.")
        }
    }

    private func handleCSV(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            if importMode == .replace {
                pendingImportURL = url
                confirmReplaceImport = true
            } else {
                presentOutcome(importFrom(url))
            }
        case .failure(let err):
            showFailure(title: "Import failed", message: err.localizedDescription)
        }
    }

    private func runPendingImport() {
        guard let url = pendingImportURL else { return }
        pendingImportURL = nil
        presentOutcome(importFrom(url))
    }

    private func importFrom(_ url: URL) -> DataActions.ImportOutcome {
        switch importDomain {
        case .armies: return DataActions.importArmiesOutcome(from: url, mode: importMode, ctx: context)
        case .paints: return DataActions.importPaintsOutcome(from: url, mode: importMode, ctx: context)
        }
    }

    private func handleJSON(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            presentOutcome(DataActions.restoreBackupOutcome(from: url, ctx: context))
        case .failure(let err):
            showFailure(title: "Restore failed", message: err.localizedDescription)
        }
    }

    private func presentOutcome(_ outcome: DataActions.ImportOutcome) {
        if outcome.success {
            importSuccessTrigger.toggle()
            if outcome.warnings.isEmpty {
                banner.show(outcome.message)
            } else {
                importOutcome = outcome
            }
        } else {
            showFailure(title: outcome.title, message: outcome.message)
        }
    }

    private func showFailure(title: String, message: String) {
        importErrorTrigger.toggle()
        alertError = (title, message)
    }

    private func exportArmiesTemplate() {
        let out = DataActions.armiesTemplateCSV()
        exportDoc = TextFileDocument(text: out.text, contentType: .commaSeparatedText)
        exportName = out.filename; exportType = .commaSeparatedText; showExporter = true
    }

    private func exportPaintsTemplate() {
        let out = DataActions.paintsTemplateCSV()
        exportDoc = TextFileDocument(text: out.text, contentType: .commaSeparatedText)
        exportName = out.filename; exportType = .commaSeparatedText; showExporter = true
    }

    private func exportArmiesCSV() {
        let out = DataActions.armiesCSV(ctx: context)
        exportDoc = TextFileDocument(text: out.text, contentType: .commaSeparatedText)
        exportName = out.filename; exportType = .commaSeparatedText; showExporter = true
    }

    private func exportPaintsCSV() {
        let out = DataActions.paintsCSV(ctx: context)
        exportDoc = TextFileDocument(text: out.text, contentType: .commaSeparatedText)
        exportName = out.filename; exportType = .commaSeparatedText; showExporter = true
    }

    private func exportBackup() {
        let out = DataActions.backupJSON(ctx: context)
        exportDoc = TextFileDocument(text: out.text, contentType: .json)
        exportName = out.filename; exportType = .json; showExporter = true
        banner.show("Backup exported")
    }
}
