import SwiftUI
import SwiftData

struct NewRosterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \Army.sortIndex) private var armies: [Army]
    @Query private var configs: [AppConfiguration]

    var prefillGame: String?
    var prefillFaction: String?
    var prefillLinkedArmyId: UUID?

    @State private var game = "40k"
    @State private var faction = ""
    @State private var battleSizeKey = "strike-force"
    @State private var name = ""
    @State private var linkedArmyId: UUID?
    @State private var errorMessage: String?

    private var factions: [String] { FactionResolver.canonicalByGame[game]?.sorted() ?? [] }
    private var battleSizes: [BattleSize] { BattleSizes.forGame(game) }
    private var matchingArmies: [Army] {
        armies.filter {
            $0.game == game && FactionResolver.normalize($0.faction) == FactionResolver.normalize(resolvedFaction)
        }
    }
    private var resolvedFaction: String { faction.isEmpty ? (factions.first ?? "Custom") : faction }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Game", selection: $game) {
                    Text("40k").tag("40k")
                }
                .onChange(of: game) { faction = ""; updateDefaultName() }

                Picker("Faction", selection: $faction) {
                    Text("Choose…").tag("")
                    ForEach(factions, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: faction) { updateDefaultName() }

                Picker("Battle size", selection: $battleSizeKey) {
                    ForEach(battleSizes) { size in
                        Text("\(size.label) (\(size.pointsLimit) pts)").tag(size.id)
                    }
                }
                .onChange(of: battleSizeKey) { updateDefaultName() }

                TextField("List name", text: $name)

                if !matchingArmies.isEmpty {
                    Picker("Link collection army", selection: $linkedArmyId) {
                        Text("None").tag(UUID?.none)
                        ForEach(matchingArmies) { army in
                            Text(army.name).tag(Optional(army.id))
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.caption)
                }
            }
            .navigationTitle("New muster")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createRoster() }
                        .accessibilityIdentifier("musterNewRoster")
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || faction.isEmpty)
                }
            }
            .onAppear {
                if let prefillGame { game = prefillGame }
                if let prefillFaction { faction = prefillFaction }
                if let prefillLinkedArmyId { linkedArmyId = prefillLinkedArmyId }
                if battleSizeKey.isEmpty {
                    battleSizeKey = configs.first?.defaultBattleSizeKey40k ?? "strike-force"
                }
                if name.isEmpty { updateDefaultName() }
            }
        }
    }

    private func updateDefaultName() {
        let f = resolvedFaction
        let sizeLabel = battleSizes.first { $0.id == battleSizeKey }?.label ?? battleSizeKey
        if name.isEmpty || name.hasSuffix(" pts") {
            name = "\(f) \(sizeLabel)"
        }
    }

    private func createRoster() {
        do {
            let roster = try RosterStore.addRoster(
                name: name,
                game: game,
                faction: resolvedFaction,
                battleSizeKey: battleSizeKey,
                linkedArmyId: linkedArmyId,
                in: context
            )
            dismiss()
            router.openMuster(rosterId: roster.id)
        } catch RosterError.nameTaken {
            errorMessage = "That list name is already taken."
        } catch RosterError.rosterLimit {
            errorMessage = "Maximum number of lists reached."
        } catch {
            errorMessage = "Could not create list."
        }
    }
}
