import SwiftUI
import SwiftData

@MainActor
struct PaintDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(BannerCenter.self) private var banner
    @Query private var armies: [Army]
    @Query private var allPaints: [Paint]

    let paintId: UUID

    @State private var confirmDelete = false
    @State private var filterTrigger = false

    private var paint: Paint? { allPaints.first { $0.id == paintId } }
    private var types: [String] {
        Array(Set(allPaints.map(\.type).filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        Group {
            if let paint { form(paint) }
            else { ContentUnavailableView("Paint not found", systemImage: "paintpalette") }
        }
        .navigationTitle(paint?.name ?? "Paint")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete \"\(paint?.name ?? "")\"?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let paint {
                    PaintStore.delete(paint, in: context)
                    dismiss()
                }
            }
        }
        .sensoryFeedback(.selection, trigger: filterTrigger)
    }

    @ViewBuilder
    private func form(_ paint: Paint) -> some View {
        @Bindable var paint = paint
        let linked = PaintStore.linkedUnitCount(source: paint.source, armies: armies)
        Form {
            Section {
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: paint.swatchHex))
                        .frame(width: 48, height: 48)
                    Spacer()
                }
            }
            Section("Paint") {
                TextField("Name", text: $paint.name)
                Picker("Type", selection: $paint.type) {
                    ForEach(typeOptions, id: \.self) { Text($0.isEmpty ? "—" : $0).tag($0) }
                }
                TextField("Brand", text: $paint.brand)
                TextField("Source", text: $paint.source)
                Stepper("Quantity: \(paint.qty)", value: $paint.qty, in: 1...9999)
                Toggle("Running low", isOn: $paint.low)
                TextField("Notes", text: $paint.notes, axis: .vertical)
                    .lineLimit(2...6)
            }
            if !paint.source.isEmpty {
                Section("Collection link") {
                    LabeledContent("Linked units", value: "\(linked)")
                    Button("Show in Collection", systemImage: "link") {
                        router.showArmies(filteredBySource: paint.source)
                        banner.show("Filtered by source: \(paint.source)")
                        filterTrigger.toggle()
                    }
                }
            }
            Section {
                Button("Delete paint", role: .destructive) { confirmDelete = true }
            }
        }
        .onDisappear { try? context.save() }
    }

    private var typeOptions: [String] {
        var seen = Set<String>()
        return (PaintType.known + types).filter { seen.insert($0).inserted }
    }
}
