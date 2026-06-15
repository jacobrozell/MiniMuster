import Foundation
import SwiftData

/// Applies parsed drafts and restore payloads to the SwiftData context. Ports the relevant
/// mutations from `js/core/store.js` (`setCollection`, `appendCollection`, `setPaints`,
/// `appendPaints`, `clearAllData`).
@MainActor
enum CollectionStore {

    // MARK: Build models from drafts

    private static func makeUnit(_ d: UnitDraft, order: Int, into ctx: ModelContext) -> Unit {
        let u = Unit(name: d.name.capped(Limits.maxStringLen), qty: d.qty,
                     source: d.source.capped(Limits.maxStringLen), state: d.state,
                     notes: d.notes.capped(Limits.maxNotesLen), spearhead: d.spearhead, order: order)
        ctx.insert(u)
        for (i, m) in d.members.prefix(Limits.maxSquadMembers).enumerated() {
            let sm = SquadMember(index: i,
                                 state: m.state,
                                 notes: m.notes)
            sm.unit = u
            ctx.insert(sm)
        }
        return u
    }

    private static func makeArmy(_ d: ArmyDraft, sortIndex: Int, into ctx: ModelContext) -> Army {
        let a = Army(name: d.name.capped(Limits.maxStringLen),
                     game: d.game.capped(Limits.maxStringLen),
                     faction: d.faction.capped(Limits.maxStringLen),
                     sortIndex: sortIndex)
        a.crestOverride = d.crestOverride.map { String($0.prefix(8)) }
        a.colorOverrideHex = d.colorOverrideHex.map(safeColor)
        if let pipe = d.customPipeline, !pipe.isEmpty {
            a.customPipeline = pipe.map { PipelineStage(key: $0.key, hex: safeColor($0.hex)) }
        }
        ctx.insert(a)
        for (i, ud) in d.units.prefix(Limits.maxUnitsPerArmy).enumerated() {
            let u = makeUnit(ud, order: i, into: ctx)
            u.army = a
        }
        return a
    }

    private static func makePaint(_ d: PaintDraft, into ctx: ModelContext) -> Paint {
        let p = Paint(name: d.name.capped(Limits.maxStringLen),
                      type: d.type.capped(Limits.maxStringLen),
                      swatchHex: safeColor(d.swatchHex), qty: d.qty,
                      brand: d.brand.capped(Limits.maxStringLen),
                      source: d.source.capped(Limits.maxStringLen),
                      notes: d.notes.capped(Limits.maxNotesLen), low: d.low)
        ctx.insert(p)
        return p
    }

    // MARK: Armies

    static func replaceArmies(_ drafts: [ArmyDraft], in ctx: ModelContext) {
        for a in (try? ctx.fetch(FetchDescriptor<Army>())) ?? [] { ctx.delete(a) }
        for (i, d) in drafts.prefix(Limits.maxArmies).enumerated() {
            _ = makeArmy(d, sortIndex: i, into: ctx)
        }
        try? ctx.save()
    }

    /// Append: incoming armies with an existing name have their units appended; else inserted.
    /// Mirrors `appendCollection`.
    static func appendArmies(_ drafts: [ArmyDraft], in ctx: ModelContext) {
        var existing = ((try? ctx.fetch(FetchDescriptor<Army>())) ?? [])
        var nextSort = (existing.map(\.sortIndex).max() ?? -1) + 1
        for d in drafts {
            if let target = existing.first(where: { $0.name == d.name }) {
                var order = (target.units.map(\.order).max() ?? -1) + 1
                for ud in d.units {
                    let u = makeUnit(ud, order: order, into: ctx)
                    u.army = target
                    order += 1
                }
            } else {
                let a = makeArmy(d, sortIndex: nextSort, into: ctx)
                nextSort += 1
                existing.append(a)
            }
        }
        try? ctx.save()
    }

    // MARK: Paints

    static func replacePaints(_ drafts: [PaintDraft], in ctx: ModelContext) {
        for p in (try? ctx.fetch(FetchDescriptor<Paint>())) ?? [] { ctx.delete(p) }
        for d in drafts.prefix(Limits.maxPaints) { _ = makePaint(d, into: ctx) }
        try? ctx.save()
    }

    /// Append: merge by lowercased name (sum qty, adopt notes if target had none).
    /// Mirrors `appendPaints`.
    static func appendPaints(_ drafts: [PaintDraft], in ctx: ModelContext) {
        var byName: [String: Paint] = [:]
        for p in (try? ctx.fetch(FetchDescriptor<Paint>())) ?? [] { byName[p.name.lowercased()] = p }
        for d in drafts {
            let k = d.name.lowercased()
            if let existing = byName[k] {
                existing.qty += d.qty
                if existing.notes.isEmpty && !d.notes.isEmpty { existing.notes = d.notes }
            } else {
                let p = makePaint(d, into: ctx)
                byName[k] = p
            }
        }
        try? ctx.save()
    }

    // MARK: Clear

    static func clearAll(in ctx: ModelContext) {
        for a in (try? ctx.fetch(FetchDescriptor<Army>())) ?? [] { ctx.delete(a) }
        for p in (try? ctx.fetch(FetchDescriptor<Paint>())) ?? [] { ctx.delete(p) }
        // Reset configuration to defaults.
        for c in (try? ctx.fetch(FetchDescriptor<AppConfiguration>())) ?? [] { ctx.delete(c) }
        ctx.insert(AppConfiguration())
        try? ctx.save()
    }
}
