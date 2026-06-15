import SwiftUI
import SwiftData

struct RosterEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let entry: RosterEntry

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Unit", value: entry.displayName)
                    Stepper("Qty: \(entry.qty)", value: Binding(
                        get: { entry.qty },
                        set: { RosterStore.setQty(entry, $0, in: context) }
                    ), in: 1...Limits.maxRosterQty)
                    LabeledContent("Points each", value: "\(entry.pointsEach)")
                    LabeledContent("Total", value: "\(entry.pointsTotal) pts")
                }
                Section {
                    Button("Remove from list", role: .destructive) {
                        RosterStore.deleteEntry(entry, in: context)
                        dismiss()
                    }
                }
            }
            .navigationTitle(entry.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
