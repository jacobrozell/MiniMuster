import Foundation
import SwiftData

/// Per-model squad tracking mutations. Ports `enableSquadMembers`, `disableSquadMembers`,
/// `updateMember`, and the member-advance logic (`js/core/store.js`, `render/armies.js`).
/// See `docs/ios-spec/04-squad-tracking.md`.
@MainActor
enum SquadStore {

    /// Enable per-model tracking (modelCount >= 2). Creates inheriting members.
    @discardableResult
    static func enable(_ unit: Unit, in ctx: ModelContext) -> Bool {
        guard !unit.hasSquadMembers, unit.modelCount >= 2 else { return false }
        for i in 0..<unit.modelCount {
            let m = SquadMember(index: i)
            m.unit = unit
            ctx.insert(m)
        }
        try? ctx.save()
        return true
    }

    static func disable(_ unit: Unit, in ctx: ModelContext) {
        for m in unit.members { ctx.delete(m) }
        try? ctx.save()
    }

    /// Set a member's state, clearing the override when it equals the unit default (inherit).
    static func setMemberState(_ unit: Unit, index: Int, state: String, in ctx: ModelContext) {
        guard let m = unit.member(at: index) else { return }
        m.state = (state == unit.state) ? nil : state
        try? ctx.save()
    }

    static func setMemberNotes(_ unit: Unit, index: Int, notes: String, in ctx: ModelContext) {
        guard let m = unit.member(at: index) else { return }
        m.notes = notes.isEmpty ? nil : notes
        try? ctx.save()
    }

    /// Advance one member one step, applying the inherit-on-match rule.
    static func advanceMember(_ unit: Unit, index: Int, pipeline: [PipelineStage], in ctx: ModelContext) {
        guard let m = unit.member(at: index) else { return }
        let cur = Members.effectiveState(of: unit, at: index)
        guard let next = Pipeline.next(after: cur, in: pipeline) else { return }
        m.state = (next == unit.state) ? nil : next
        try? ctx.save()
    }
}
