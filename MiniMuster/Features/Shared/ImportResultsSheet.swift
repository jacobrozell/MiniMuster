import SwiftUI

/// Import summary presented after CSV import from Settings.
struct ImportResultsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let message: String
    let warnings: [String]
    let failed: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(message, systemImage: failed ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(failed ? .red : .primary)
                }
                if !warnings.isEmpty {
                    Section("Warnings (\(warnings.count))") {
                        ForEach(warnings, id: \.self) { Text($0).font(.caption) }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
