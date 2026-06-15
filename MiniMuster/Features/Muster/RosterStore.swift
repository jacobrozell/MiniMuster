import Foundation
import SwiftData

enum RosterError: Error, Equatable {
    case nameTaken
    case nameEmpty
    case rosterLimit
    case entryLimit
    case catalogUnitNotFound
}

@MainActor
enum RosterStore {
    @discardableResult
    static func addRoster(name: String, game: String, faction: String,
                          battleSizeKey: String, linkedArmyId: UUID?,
                          in ctx: ModelContext) throws -> Roster {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw RosterError.nameEmpty }
        let all = (try? ctx.fetch(FetchDescriptor<Roster>())) ?? []
        guard all.count < Limits.maxRosters else { throw RosterError.rosterLimit }
        guard !all.contains(where: { $0.name == trimmed }) else { throw RosterError.nameTaken }

        let roster = Roster(name: trimmed, game: game, faction: faction, battleSizeKey: battleSizeKey)
        roster.linkedArmyId = linkedArmyId
        roster.sortIndex = (all.map(\.sortIndex).max() ?? -1) + 1
        roster.catalogVersion = UnitCatalogLoader.version
        ctx.insert(roster)
        try ctx.save()
        return roster
    }

    @discardableResult
    static func rename(_ roster: Roster, to newName: String, in ctx: ModelContext) throws -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != roster.name else { return false }
        let all = (try? ctx.fetch(FetchDescriptor<Roster>())) ?? []
        guard !all.contains(where: { $0 !== roster && $0.name == trimmed }) else { throw RosterError.nameTaken }
        roster.name = trimmed.capped(Limits.maxStringLen)
        roster.touch()
        try ctx.save()
        return true
    }

    static func setLinkedArmy(_ roster: Roster, armyId: UUID?, in ctx: ModelContext) {
        roster.linkedArmyId = armyId
        roster.touch()
        try? ctx.save()
    }

    static func delete(_ roster: Roster, in ctx: ModelContext) {
        ctx.delete(roster)
        try? ctx.save()
    }

    @discardableResult
    static func duplicate(_ roster: Roster, in ctx: ModelContext) throws -> Roster {
        let copyName = uniqueName(base: "\(roster.name) copy", in: ctx)
        let copy = try addRoster(name: copyName, game: roster.game, faction: roster.faction,
                                 battleSizeKey: roster.battleSizeKey, linkedArmyId: roster.linkedArmyId,
                                 in: ctx)
        for e in roster.orderedEntries {
            _ = try addEntry(from: e.catalogUnitId, qty: e.qty, to: copy, in: ctx)
        }
        return copy
    }

    @discardableResult
    static func addEntry(from catalogUnitId: String, qty: Int = 1,
                         to roster: Roster, in ctx: ModelContext) throws -> RosterEntry {
        guard roster.entries.count < Limits.maxEntriesPerRoster else { throw RosterError.entryLimit }
        guard let unit = UnitCatalogLoader.unit(id: catalogUnitId) else { throw RosterError.catalogUnitNotFound }

        if let existing = roster.entries.first(where: { $0.catalogUnitId == catalogUnitId }) {
            setQty(existing, existing.qty + qty, in: ctx)
            return existing
        }

        let entry = RosterEntry(
            catalogUnitId: unit.id,
            displayName: unit.name,
            qty: qty,
            pointsEach: unit.basePoints,
            sortIndex: (roster.entries.map(\.sortIndex).max() ?? -1) + 1
        )
        entry.roster = roster
        ctx.insert(entry)
        roster.touch()
        roster.catalogVersion = UnitCatalogLoader.version
        try ctx.save()
        return entry
    }

    static func setQty(_ entry: RosterEntry, _ qty: Int, in ctx: ModelContext) {
        entry.qty = max(1, min(qty, Limits.maxRosterQty))
        entry.roster?.touch()
        try? ctx.save()
    }

    static func deleteEntry(_ entry: RosterEntry, in ctx: ModelContext) {
        entry.roster?.touch()
        ctx.delete(entry)
        try? ctx.save()
    }

    static func importMissingToCollection(roster: Roster,
                                          pipeline: [PipelineStage],
                                          in ctx: ModelContext) throws -> Int {
        let firstStage = pipeline.first?.key ?? "Unassembled"
        let army = try resolveLinkedArmy(for: roster, in: ctx)
        let matches = CollectionMatcher.matchAll(roster: roster, armies: fetchArmies(ctx), in: ctx)
        var added = 0
        for (entry, result) in matches where result.status == .missing || result.status == .partial {
            let need = result.requiredQty - result.ownedQty
            guard need > 0 else { continue }
            let catalog = UnitCatalogLoader.unit(id: entry.catalogUnitId)
            let name = catalog?.name ?? entry.displayName
            _ = ArmyStore.addUnit(to: army, name: name, qty: 1, source: roster.name, state: firstStage, in: ctx)
            added += 1
        }
        return added
    }

    private static func fetchArmies(_ ctx: ModelContext) -> [Army] {
        (try? ctx.fetch(FetchDescriptor<Army>())) ?? []
    }

    private static func resolveLinkedArmy(for roster: Roster, in ctx: ModelContext) throws -> Army {
        if let id = roster.linkedArmyId,
           let army = fetchArmies(ctx).first(where: { $0.id == id }) { return army }
        guard ArmyStore.addArmy(name: roster.name, game: roster.game, faction: roster.faction, in: ctx),
              let army = fetchArmies(ctx).first(where: { $0.name == roster.name }) else {
            throw RosterError.nameTaken
        }
        roster.linkedArmyId = army.id
        try ctx.save()
        return army
    }

    private static func uniqueName(base: String, in ctx: ModelContext) -> String {
        let all = (try? ctx.fetch(FetchDescriptor<Roster>())) ?? []
        let names = Set(all.map(\.name))
        if !names.contains(base) { return base }
        var n = 2
        while names.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }
}
