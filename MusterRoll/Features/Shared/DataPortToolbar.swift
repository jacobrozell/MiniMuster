import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Adds an Import/Export/Sample menu to a screen and wires the file pickers + result alert.
/// Minimal M5 wiring; the richer flows (mode dialogs, results sheet) are specced in
/// `docs/ios-spec/08-import-export.md`.
struct DataPortToolbar: ViewModifier {
    enum Domain { case armies, paints }
    let domain: Domain

    @Environment(\.modelContext) private var ctx

    @State private var importMode: DataActions.Mode = .replace
    @State private var showCSVImporter = false
    @State private var showJSONImporter = false
    @State private var showExporter = false
    @State private var exportDoc = TextFileDocument(text: "")
    @State private var exportName = "export"
    @State private var exportType: UTType = .commaSeparatedText
    @State private var message: String?
    @State private var confirmClear = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Data", systemImage: "tray.and.arrow.down") {
                        Button("Import \(label) (replace)…") { importMode = .replace; showCSVImporter = true }
                        Button("Import \(label) (append)…") { importMode = .append; showCSVImporter = true }
                        Button("Export \(label) CSV") { exportCSV() }
                        Divider()
                        Button("Load sample data") { message = DataActions.loadSample(ctx: ctx) }
                        if domain == .armies {
                            Divider()
                            Button("Full backup (JSON)") { exportBackup() }
                            Button("Restore backup…") { showJSONImporter = true }
                            Button("Clear all data", role: .destructive) { confirmClear = true }
                        }
                    }
                }
            }
            .fileImporter(isPresented: $showCSVImporter,
                          allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                handle(result) { url in
                    domain == .armies
                        ? DataActions.importArmies(from: url, mode: importMode, ctx: ctx)
                        : DataActions.importPaints(from: url, mode: importMode, ctx: ctx)
                }
            }
            .fileImporter(isPresented: $showJSONImporter, allowedContentTypes: [.json]) { result in
                handle(result) { DataActions.restoreBackup(from: $0, ctx: ctx) }
            }
            .fileExporter(isPresented: $showExporter, document: exportDoc,
                          contentType: exportType, defaultFilename: exportName) { _ in }
            .alert("Data", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: { Text(message ?? "") }
            .confirmationDialog("Delete all armies, paints, and settings on this device?",
                                isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear all", role: .destructive) {
                    CollectionStore.clearAll(in: ctx)
                    message = "All data cleared."
                }
            }
    }

    private var label: String { domain == .armies ? "Armies" : "Paints" }

    private func handle(_ result: Result<URL, Error>, _ action: (URL) -> String) {
        switch result {
        case .success(let url): message = action(url)
        case .failure(let err): message = err.localizedDescription
        }
    }

    private func exportCSV() {
        let out = domain == .armies ? DataActions.armiesCSV(ctx: ctx) : DataActions.paintsCSV(ctx: ctx)
        exportDoc = TextFileDocument(text: out.text, contentType: .commaSeparatedText)
        exportName = out.filename
        exportType = .commaSeparatedText
        showExporter = true
    }

    private func exportBackup() {
        let out = DataActions.backupJSON(ctx: ctx)
        exportDoc = TextFileDocument(text: out.text, contentType: .json)
        exportName = out.filename
        exportType = .json
        showExporter = true
    }
}

extension View {
    func dataPortToolbar(_ domain: DataPortToolbar.Domain) -> some View {
        modifier(DataPortToolbar(domain: domain))
    }
}
