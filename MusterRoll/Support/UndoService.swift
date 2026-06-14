import Foundation
import SwiftData

/// Explicit undo stack matching the web's scope (`js/core/store.js`): unit delete, army
/// delete, unit state change, and batch state change (bulk advance). Name/qty/source/notes
/// edits are intentionally NOT undoable. See `docs/ios-spec/09 §4`.
@Observable
@MainActor
final class UndoService {
    /// Shared instance so `ArmyStore` (static funcs) can record without threading it through
    /// every call. The same instance is injected into the environment for the Undo button.
    static let shared = UndoService()

    struct MemberSnap: Sendable { var index: Int; var state: String?; var notes: String? }
    struct UnitSnap: Sendable {
        var id: UUID; var name: String; var qty: Int; var source: String; var state: String
        var notes: String; var spearhead: Bool?; var order: Int; var armyName: String
        var members: [MemberSnap]
    }
    struct ArmySnap: Sendable {
        var name: String; var game: String; var faction: String
        var crestOverride: String?; var colorOverrideHex: String?
        var customPipeline: [PipelineStage]?; var sortIndex: Int; var isCollapsed: Bool
        var units: [UnitSnap]
    }

    enum Action {
        case deleteUnit(UnitSnap)
        case deleteArmy(ArmySnap)
        case unitState(id: UUID, previous: String)
        case batchStates([(id: UUID, previous: String)])
    }

    private(set) var stack: [Action] = []
    private let maxDepth = 30

    var canUndo: Bool { !stack.isEmpty }

    func record(_ action: Action) {
        stack.append(action)
        if stack.count > maxDepth { stack.removeFirst(stack.count - maxDepth) }
    }

    func clear() { stack.removeAll() }

    static func snapshot(_ unit: Unit) -> UnitSnap {
        UnitSnap(id: unit.id, name: unit.name, qty: unit.qty, source: unit.source,
                 state: unit.state, notes: unit.notes, spearhead: unit.spearhead,
                 order: unit.order, armyName: unit.army?.name ?? "",
                 members: unit.orderedMembers.map { MemberSnap(index: $0.index, state: $0.state, notes: $0.notes) })
    }

    static func snapshot(_ army: Army) -> ArmySnap {
        ArmySnap(name: army.name, game: army.game, faction: army.faction,
                 crestOverride: army.crestOverride, colorOverrideHex: army.colorOverrideHex,
                 customPipeline: army.customPipeline, sortIndex: army.sortIndex,
                 isCollapsed: army.isCollapsed, units: army.orderedUnits.map(snapshot))
    }

    /// Reverse the most recent action. Returns a short description for a toast, or nil.
    @discardableResult
    func undo(in ctx: ModelContext) -> String? {
        guard let action = stack.popLast() else { return nil }
        switch action {
        case .deleteUnit(let snap):
            guard let army = army(named: snap.armyName, in: ctx) else { return nil }
            restore(snap, into: army, ctx: ctx)
            try? ctx.save()
            return "Restored \(snap.name)"
        case .deleteArmy(let snap):
            let army = Army(name: snap.name, game: snap.game, faction: snap.faction, sortIndex: snap.sortIndex)
            army.crestOverride = snap.crestOverride
            army.colorOverrideHex = snap.colorOverrideHex
            army.customPipeline = snap.customPipeline
            army.isCollapsed = snap.isCollapsed
            ctx.insert(army)
            for u in snap.units { restore(u, into: army, ctx: ctx) }
            try? ctx.save()
            return "Restored \(snap.name)"
        case .unitState(let id, let previous):
            unit(id: id, in: ctx)?.state = previous
            try? ctx.save()
            return "Undone"
        case .batchStates(let changes):
            for c in changes { unit(id: c.id, in: ctx)?.state = c.previous }
            try? ctx.save()
            return "Undone"
        }
    }

    private func restore(_ snap: UnitSnap, into army: Army, ctx: ModelContext) {
        let u = Unit(name: snap.name, qty: snap.qty, source: snap.source, state: snap.state,
                     notes: snap.notes, spearhead: snap.spearhead, order: snap.order)
        u.id = snap.id
        u.army = army
        ctx.insert(u)
        for m in snap.members {
            let sm = SquadMember(index: m.index, state: m.state, notes: m.notes)
            sm.unit = u
            ctx.insert(sm)
        }
    }

    private func army(named name: String, in ctx: ModelContext) -> Army? {
        try? ctx.fetch(FetchDescriptor<Army>(predicate: #Predicate { $0.name == name })).first
    }

    private func unit(id: UUID, in ctx: ModelContext) -> Unit? {
        try? ctx.fetch(FetchDescriptor<Unit>(predicate: #Predicate { $0.id == id })).first
    }
}
