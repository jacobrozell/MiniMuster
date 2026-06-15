import Foundation
import SwiftData

struct CollectionMatchResult: Sendable {
    enum Status: Sendable { case owned, partial, missing, unknown }
    let entryId: UUID
    let status: Status
    let ownedQty: Int
    let requiredQty: Int
    let matchedUnitIds: [UUID]
}

enum CollectionMatcher {
    static func matchAll(roster: Roster, armies: [Army], in ctx: ModelContext) -> [(RosterEntry, CollectionMatchResult)] {
        let units = scopedCollectionUnits(roster: roster, armies: armies)
        return roster.orderedEntries.map { entry in
            (entry, match(entry: entry, collectionUnits: units))
        }
    }

    static func fieldablePercent(roster: Roster, armies: [Army], in ctx: ModelContext) -> Int {
        let results = matchAll(roster: roster, armies: armies, in: ctx)
        guard !results.isEmpty else { return 0 }
        let owned = results.filter { $0.1.status == .owned }.count
        return Int((Double(owned) / Double(results.count) * 100).rounded())
    }

    static func match(entry: RosterEntry, collectionUnits: [Unit]) -> CollectionMatchResult {
        let catalog = UnitCatalogLoader.unit(id: entry.catalogUnitId)
        let required = requiredModels(entry: entry, catalog: catalog)
        let matched = collectionUnits.filter { unit in
            UnitNameMatch.matches(collectionUnitName: unit.name,
                                  catalogName: entry.displayName,
                                  aliases: catalog?.aliases ?? [])
        }
        let owned = matched.reduce(0) { $0 + ModelCount.of(name: $1.name, qty: $1.qty) }
        let status: CollectionMatchResult.Status = {
            if catalog == nil { return .unknown }
            if owned >= required { return .owned }
            if owned > 0 { return .partial }
            return .missing
        }()
        return CollectionMatchResult(
            entryId: entry.id,
            status: status,
            ownedQty: owned,
            requiredQty: required,
            matchedUnitIds: matched.map(\.id)
        )
    }

    private static func requiredModels(entry: RosterEntry, catalog: CatalogUnit?) -> Int {
        let perEntry = catalog?.modelCount ?? 1
        return entry.qty * max(1, perEntry)
    }

    private static func scopedCollectionUnits(roster: Roster, armies: [Army]) -> [Unit] {
        if let id = roster.linkedArmyId, let army = armies.first(where: { $0.id == id }) {
            return army.units
        }
        let f = FactionResolver.normalize(roster.faction)
        return armies.filter {
            $0.game == roster.game && FactionResolver.normalize($0.faction) == f
        }.flatMap(\.units)
    }
}
