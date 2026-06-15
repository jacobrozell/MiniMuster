import Foundation
import SwiftData

/// Army/unit mutations for the Armies tab. Ports the relevant store methods from
/// `js/core/store.js` (`addArmy`, `renameArmy`, `removeArmy`, `addUnit`, `updateUnit`,
/// `duplicateUnit`, `moveUnit`, `removeUnit`, `setAllUnitsState`, `mergeArmyDuplicates`)
/// and the advance helpers from `render/armies.js`.
///
/// Undo (M6) is not wired yet; deletes/state changes route through here so it can be added
/// without touching the views.
@MainActor
enum ArmyStore {

    // MARK: Armies

    /// Insert a new army. Returns false if the name is already taken (mirrors `addArmy`).
    @discardableResult
    static func addArmy(name: String, game: String, faction: String, in ctx: ModelContext) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let all = (try? ctx.fetch(FetchDescriptor<Army>())) ?? []
        guard !all.contains(where: { $0.name == trimmed }) else { return false }
        let army = Army(name: trimmed.capped(Limits.maxStringLen),
                        game: game, faction: faction,
                        sortIndex: (all.map(\.sortIndex).max() ?? -1) + 1)
        ctx.insert(army)
        try? ctx.save()
        return true
    }

    /// Rename an army, rejecting blank or duplicate names (mirrors `renameArmy`).
    @discardableResult
    static func rename(_ army: Army, to newName: String, in ctx: ModelContext) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != army.name else { return false }
        let all = (try? ctx.fetch(FetchDescriptor<Army>())) ?? []
        guard !all.contains(where: { $0 !== army && $0.name == trimmed }) else { return false }
        army.name = trimmed.capped(Limits.maxStringLen)
        try? ctx.save()
        return true
    }

    static func delete(_ army: Army, in ctx: ModelContext) {
        UndoService.shared.record(.deleteArmy(UndoService.snapshot(army)))
        ctx.delete(army)
        try? ctx.save()
    }

    static func toggleCollapse(_ army: Army, in ctx: ModelContext) {
        army.isCollapsed.toggle()
        try? ctx.save()
    }

    static func setCollapseAll(_ collapsed: Bool, in ctx: ModelContext) {
        for a in (try? ctx.fetch(FetchDescriptor<Army>())) ?? [] { a.isCollapsed = collapsed }
        try? ctx.save()
    }

    /// Clear crest/colour overrides so the army falls back to faction defaults
    /// (mirrors `reapplyArmyFactionDefaults` / the ◐ action).
    static func resetTheme(_ army: Army, in ctx: ModelContext) {
        army.crestOverride = nil
        army.colorOverrideHex = nil
        try? ctx.save()
    }

    // MARK: Units

    @discardableResult
    static func addUnit(to army: Army, name: String, qty: Int, source: String, state: String,
                        in ctx: ModelContext) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let usesSpearhead = army.units.contains { $0.spearhead != nil }
        let unit = Unit(name: trimmed.capped(Limits.maxStringLen),
                        qty: max(1, qty), source: source.capped(Limits.maxStringLen),
                        state: state, spearhead: usesSpearhead ? false : nil,
                        order: (army.units.map(\.order).max() ?? -1) + 1)
        unit.army = army
        ctx.insert(unit)
        try? ctx.save()
        return true
    }

    static func delete(_ unit: Unit, in ctx: ModelContext) {
        UndoService.shared.record(.deleteUnit(UndoService.snapshot(unit)))
        let army = unit.army
        PhotoStore.purgeFiles(for: unit)
        ctx.delete(unit)
        if let army { renumber(army) }
        try? ctx.save()
    }

    /// Deep-copy a unit (including members) immediately after it (mirrors `duplicateUnit`).
    @discardableResult
    static func duplicate(_ unit: Unit, in ctx: ModelContext) -> Unit? {
        guard let army = unit.army else { return nil }
        let copy = Unit(name: unit.name, qty: unit.qty, source: unit.source,
                        state: unit.state, notes: unit.notes, spearhead: unit.spearhead,
                        order: unit.order + 1)
        copy.army = army
        ctx.insert(copy)
        for m in unit.orderedMembers {
            let cm = SquadMember(index: m.index, state: m.state, notes: m.notes)
            cm.unit = copy
            ctx.insert(cm)
        }
        // Shift later units down by one to make room.
        for u in army.units where u !== copy && u.order > unit.order { u.order += 1 }
        renumber(army)
        try? ctx.save()
        return copy
    }

    /// Move a unit to another army (mirrors `moveUnit`).
    @discardableResult
    static func move(_ unit: Unit, to destination: Army, in ctx: ModelContext) -> Bool {
        guard let source = unit.army, source !== destination else { return false }
        unit.army = destination
        unit.order = (destination.units.map(\.order).max() ?? -1) + 1
        renumber(source)
        try? ctx.save()
        return true
    }

    static func setState(_ unit: Unit, _ state: String, in ctx: ModelContext) {
        guard unit.state != state else { return }
        UndoService.shared.record(.unitState(id: unit.id, previous: unit.state))
        let previous = unit.state
        unit.state = state
        StageEventStore.record(unit: unit, stageKey: state, previousStageKey: previous,
                               memberIndex: nil, in: ctx)
        try? ctx.save()
    }

    static func setQty(_ unit: Unit, _ qty: Int, in ctx: ModelContext) {
        unit.qty = max(1, min(9999, qty))
        resizeMembers(unit, in: ctx)
        try? ctx.save()
    }

    static func setSpearhead(_ unit: Unit, _ value: Bool, in ctx: ModelContext) {
        unit.spearhead = value
        try? ctx.save()
    }

    // MARK: Advance

    static func advance(_ unit: Unit, pipeline: [PipelineStage], in ctx: ModelContext) {
        guard Pipeline.canAdvance(unit, pipeline) else { return }
        let previousUnitState = unit.state
        let previousMemberStates = Dictionary(uniqueKeysWithValues:
            unit.orderedMembers.map { ($0.index, Members.effectiveState(of: unit, at: $0.index)) })
        Pipeline.advanceOneStep(unit, pipeline)
        StageEventStore.recordAdvance(of: unit, previousUnitState: previousUnitState,
                                      previousMemberStates: previousMemberStates, in: ctx)
        try? ctx.save()
    }

    /// Advance a chosen set of units one step (edit-mode batch). Returns count advanced.
    @discardableResult
    static func advance(_ units: [Unit], pipeline: [PipelineStage], in ctx: ModelContext) -> Int {
        let targets = units.filter { Pipeline.canAdvance($0, pipeline) }
        guard !targets.isEmpty else { return 0 }
        UndoService.shared.record(.batchStates(targets.map { ($0.id, $0.state) }))
        for u in targets { Pipeline.advanceOneStep(u, pipeline) }
        try? ctx.save()
        return targets.count
    }

    /// Advance every unit in an army one step (mirrors the `bulk-next` action).
    @discardableResult
    static func advanceAll(in army: Army, global: [PipelineStage]?, in ctx: ModelContext) -> Int {
        let pipeline = Pipeline.forArmy(army, global: global)
        let targets = army.units.filter { Pipeline.canAdvance($0, pipeline) }
        guard !targets.isEmpty else { return 0 }
        UndoService.shared.record(.batchStates(targets.map { ($0.id, $0.state) }))
        for u in targets { Pipeline.advanceOneStep(u, pipeline) }
        try? ctx.save()
        return targets.count
    }

    /// Advance every unit in a set one step (mirrors `advanceVisibleUnits`). Returns count.
    @discardableResult
    static func advanceUnits(_ units: [Unit], global: [PipelineStage]?, in ctx: ModelContext) -> Int {
        let targets = units.filter { Pipeline.canAdvance($0, Pipeline.resolve($0.army?.customPipeline ?? global)) }
        guard !targets.isEmpty else { return 0 }
        UndoService.shared.record(.batchStates(targets.map { ($0.id, $0.state) }))
        for u in targets {
            Pipeline.advanceOneStep(u, Pipeline.resolve(u.army?.customPipeline ?? global))
        }
        try? ctx.save()
        return targets.count
    }

    // MARK: Merge duplicates

    /// Merge unit rows with identical name/source/state/spearhead/members (mirrors
    /// `mergeArmyDuplicates`). Returns the number of rows removed.
    @discardableResult
    static func mergeDuplicates(in army: Army, ctx: ModelContext) -> Int {
        var seen: [String: Unit] = [:]
        var order: [Unit] = []
        var removed = 0
        for u in army.orderedUnits {
            let memberKey = u.orderedMembers.map { "\($0.index):\($0.state ?? ""):\($0.notes ?? "")" }.joined(separator: "|")
            let key = "\(u.name)\u{0}\(u.source)\u{0}\(u.state)\u{0}\(u.spearhead.map(String.init) ?? "")\u{0}\(memberKey)"
            if let target = seen[key] {
                target.qty += u.qty
                if target.notes.isEmpty && !u.notes.isEmpty { target.notes = u.notes }
                ctx.delete(u)
                removed += 1
            } else {
                seen[key] = u
                order.append(u)
            }
        }
        if removed > 0 {
            for (i, u) in order.enumerated() { u.order = i }
            try? ctx.save()
        }
        return removed
    }

    // MARK: Helpers

    /// Renumber a unit's order to a contiguous 0..<count by current order.
    static func renumber(_ army: Army) {
        for (i, u) in army.orderedUnits.enumerated() { u.order = i }
    }

    static func resizeMembers(_ unit: Unit, in ctx: ModelContext) {
        guard unit.hasSquadMembers else { return }
        let n = unit.modelCount
        let existing = unit.orderedMembers
        if existing.count > n {
            for m in existing[n...] { ctx.delete(m) }
        } else if existing.count < n {
            for i in existing.count..<n {
                let m = SquadMember(index: i)
                m.unit = unit
                ctx.insert(m)
            }
        }
    }
}
