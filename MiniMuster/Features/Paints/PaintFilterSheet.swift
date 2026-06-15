import SwiftUI

struct PaintFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var cfg: AppConfiguration

    let types: [String]
    let brands: [String]

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $cfg.paintTypeFilter) {
                    ForEach(["All"] + types, id: \.self) { Text($0).tag($0) }
                }
                Picker("Brand", selection: $cfg.paintBrandFilter) {
                    ForEach(["All"] + brands, id: \.self) { Text($0).tag($0) }
                }
                Toggle("Running low only", isOn: $cfg.paintLowOnly)
                Section {
                    Button("Clear filters", role: .destructive) {
                        cfg.paintTypeFilter = "All"
                        cfg.paintBrandFilter = "All"
                        cfg.paintLowOnly = false
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Paint filters")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { try? context.save(); dismiss() }
                }
            }
        }
    }
}
