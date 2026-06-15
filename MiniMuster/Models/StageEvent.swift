import Foundation
import SwiftData

/// Automatic log when a unit or squad member painting state changes.
@Model
final class StageEvent {
    var id: UUID = UUID()
    var occurredAt: Date = Date()
    var stageKey: String = ""
    var previousStageKey: String?
    /// nil = unit-level; non-nil = squad member index.
    var memberIndex: Int?
    var unit: Unit?

    init(stageKey: String, previousStageKey: String?, memberIndex: Int? = nil) {
        self.stageKey = stageKey
        self.previousStageKey = previousStageKey
        self.memberIndex = memberIndex
    }
}
