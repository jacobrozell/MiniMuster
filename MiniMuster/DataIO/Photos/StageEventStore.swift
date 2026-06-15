import Foundation
import SwiftData

@MainActor
enum StageEventStore {
    static func record(unit: Unit, stageKey: String, previousStageKey: String?,
                       memberIndex: Int?, in ctx: ModelContext) {
        let event = StageEvent(stageKey: stageKey, previousStageKey: previousStageKey, memberIndex: memberIndex)
        event.unit = unit
        ctx.insert(event)
    }

    static func recordAdvance(of unit: Unit, previousUnitState: String,
                              previousMemberStates: [Int: String], in ctx: ModelContext) {
        if unit.state != previousUnitState {
            record(unit: unit, stageKey: unit.state, previousStageKey: previousUnitState,
                   memberIndex: nil, in: ctx)
        }
        for member in unit.orderedMembers {
            let previous = previousMemberStates[member.index] ?? previousUnitState
            let next = Members.effectiveState(of: unit, at: member.index)
            guard previous != next else { continue }
            record(unit: unit, stageKey: next, previousStageKey: previous,
                   memberIndex: member.index, in: ctx)
        }
    }
}
