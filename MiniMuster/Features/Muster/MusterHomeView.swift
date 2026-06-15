import SwiftUI
import SwiftData

@MainActor
struct MusterHomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(BannerCenter.self) private var banner
    @Query(sort: \Roster.sortIndex) private var rosters: [Roster]
    @Query(sort: \Army.sortIndex) private var armies: [Army]
    @Query private var configs: [AppConfiguration]

    @Binding var selectedRosterId: UUID?
    var onSelectRoster: (UUID) -> Void = { _ in }

    @State private var showNew = false
    @State private var search = ""
    @State private var rosterToRename: Roster?
    @State private var rosterToDelete: Roster?

    private var overrides: [FactionPresetOverride] { configs.first?.factionOverrides ?? [] }
    private var filtered: [Roster] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return rosters }
        return rosters.filter {
            $0.name.lowercased().contains(q) || $0.faction.lowercased().contains(q)
        }
    }
    private var usesPadSidebarList: Bool {
        AdaptiveLayout.usesSidebarListStyle(horizontalSizeClass)
    }

    var body: some View {
        Group {
            if rosters.isEmpty { emptyState }
            else { listContent }
        }
        .navigationTitle("Muster")
        .searchable(text: $search, prompt: "Lists, factions…")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New list", systemImage: "plus") { showNew = true }
                    .accessibilityIdentifier("musterNewList")
            }
        }
        .sheet(isPresented: $showNew) { NewRosterSheet() }
        .sheet(isPresented: Binding(
            get: { rosterToRename != nil },
            set: { if !$0 { rosterToRename = nil } }
        )) {
            if let roster = rosterToRename {
                RenameRosterSheet(current: roster.name) { newName in
                    do {
                        return try RosterStore.rename(roster, to: newName, in: context)
                    } catch {
                        return false
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .confirmationDialog("Delete \"\(rosterToDelete?.name ?? "")\"?",
                            isPresented: Binding(get: { rosterToDelete != nil },
                                                 set: { if !$0 { rosterToDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let roster = rosterToDelete {
                    if roster.id == selectedRosterId { selectedRosterId = nil }
                    RosterStore.delete(roster, in: context)
                }
                rosterToDelete = nil
            }
            Button("Cancel", role: .cancel) { rosterToDelete = nil }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No lists yet", systemImage: "flag")
        } description: {
            Text("Muster an army list — count points, see what you can field.")
        }         actions: {
            Button("New muster", systemImage: "plus") { showNew = true }
                .accessibilityIdentifier("musterNewList")
        }
    }

    private var listContent: some View {
        Group {
            if usesPadSidebarList {
                List(filtered, selection: $selectedRosterId) { roster in
                    rosterRowContent(roster)
                }
                .listStyle(.sidebar)
            } else {
                List(filtered) { roster in
                    rosterRowContent(roster)
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    @ViewBuilder
    private func rosterRowContent(_ roster: Roster) -> some View {
        rosterRow(roster)
            .tag(roster.id)
            .listSidebarSelection(isSelected: selectedRosterId == roster.id,
                                  enabled: usesPadSidebarList)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelectRoster(roster.id)
            }
            .contextMenu {
                Button("Duplicate", systemImage: "doc.on.doc") {
                    duplicate(roster)
                }
                Button("Rename", systemImage: "pencil") { rosterToRename = roster }
                Button("Delete", systemImage: "trash", role: .destructive) { rosterToDelete = roster }
            }
    }

    @ViewBuilder
    private func rosterRow(_ roster: Roster) -> some View {
        let pres = roster.presentation(overrides: overrides)
        let total = RosterPoints.total(roster.orderedEntries)
        let limit = RosterPoints.limit(for: roster)
        let fieldable = CollectionMatcher.fieldablePercent(roster: roster, armies: armies, in: context)
        let showsFieldable = roster.linkedArmyId != nil || armies.contains {
            $0.game == roster.game && FactionResolver.normalize($0.faction) == FactionResolver.normalize(roster.faction)
        }
        HStack(spacing: 12) {
            CrestBadge(text: pres.crest, colorHex: pres.colorHex)
            VStack(alignment: .leading, spacing: 2) {
                Text(roster.name)
                    .font(.headline)
                    .lineLimit(2)
                Text("\(roster.faction) · \(total) / \(limit) pts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if !roster.entries.isEmpty, showsFieldable {
                ProgressRing(percent: fieldable, diameter: 32)
                    .accessibilityLabel("\(fieldable) percent fieldable")
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rosterAccessibilityLabel(
            roster: roster, total: total, limit: limit, fieldable: fieldable, showsFieldable: showsFieldable
        ))
        .accessibilityHint("Opens list editor")
    }

    private func rosterAccessibilityLabel(
        roster: Roster, total: Int, limit: Int, fieldable: Int, showsFieldable: Bool
    ) -> String {
        var label = "\(roster.name), \(roster.faction), \(total) of \(limit) points"
        if showsFieldable { label += ", \(fieldable) percent fieldable" }
        return label
    }

    private func duplicate(_ roster: Roster) {
        do {
            let copy = try RosterStore.duplicate(roster, in: context)
            banner.show("Duplicated \"\(copy.name)\"")
        } catch {
            banner.show("Could not duplicate list")
        }
    }
}

struct RenameRosterSheet: View {
    @Environment(\.dismiss) private var dismiss
    let current: String
    let onRename: (String) -> Bool

    @State private var name: String
    @State private var error = false

    init(current: String, onRename: @escaping (String) -> Bool) {
        self.current = current
        self.onRename = onRename
        _name = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("List name", text: $name)
                if error { Text("That name is taken.").foregroundStyle(.red).font(.caption) }
            }
            .navigationTitle("Rename list")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if onRename(name) { dismiss() } else { error = true } }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
