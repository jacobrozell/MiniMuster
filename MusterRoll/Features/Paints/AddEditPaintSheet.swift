import SwiftUI

/// Add/edit paint form. Mirrors `paintForm` (`js/render/paints.js`).
struct AddEditPaintSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existing: Paint?
    let extraTypes: [String]
    /// Returns true on success; false on duplicate-name conflict.
    let onSave: (_ name: String, _ type: String, _ brand: String, _ source: String,
                 _ qty: Int, _ notes: String, _ low: Bool) -> Bool

    @State private var name: String
    @State private var type: String
    @State private var brand: String
    @State private var source: String
    @State private var qty: Int
    @State private var notes: String
    @State private var low: Bool
    @State private var error = false

    init(existing: Paint?, extraTypes: [String],
         onSave: @escaping (String, String, String, String, Int, String, Bool) -> Bool) {
        self.existing = existing
        self.extraTypes = extraTypes
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _type = State(initialValue: existing?.type ?? "")
        _brand = State(initialValue: existing?.brand ?? "")
        _source = State(initialValue: existing?.source ?? "")
        _qty = State(initialValue: existing?.qty ?? 1)
        _notes = State(initialValue: existing?.notes ?? "")
        _low = State(initialValue: existing?.low ?? false)
    }

    private var typeOptions: [String] {
        var seen = Set<String>()
        return (PaintType.known + extraTypes).filter { seen.insert($0).inserted }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $type) {
                    ForEach(typeOptions, id: \.self) { Text($0.isEmpty ? "—" : $0).tag($0) }
                }
                TextField("Brand", text: $brand)
                TextField("Source", text: $source)
                Stepper("Quantity: \(qty)", value: $qty, in: 1...9999)
                Toggle("Running low / need more", isOn: $low)
                TextField("Notes", text: $notes, axis: .vertical)
                if error { Text("A paint with that name already exists.").foregroundStyle(.red).font(.caption) }
            }
            .navigationTitle(existing == nil ? "Add paint" : "Edit paint")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if onSave(name, type, brand, source, qty, notes, low) { dismiss() }
                        else { error = true }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
