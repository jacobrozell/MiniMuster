import Foundation
import SwiftData

/// A JPEG checkpoint attached to a unit. Bytes live on disk; this row stores metadata only.
@Model
final class ModelPhoto {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    /// Pipeline stage key at capture time (e.g. "Primed").
    var stageKey: String = ""
    var caption: String = ""
    /// File name relative to `PhotoFileStore.directory` (e.g. `a1b2….jpg`).
    var fileName: String = ""
    var isCover: Bool = false
    var sortIndex: Int = 0
    /// nil = unit-level; non-nil = per-model index when squad tracking is on.
    var memberIndex: Int?

    var unit: Unit?

    init(stageKey: String, fileName: String, memberIndex: Int? = nil) {
        self.stageKey = stageKey
        self.fileName = fileName
        self.memberIndex = memberIndex
    }
}
