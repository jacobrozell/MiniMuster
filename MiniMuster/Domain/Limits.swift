import Foundation
import CoreGraphics

/// Import / backup size and collection caps. Ports `js/core/limits.js`.
/// There is no localStorage quota on iOS, so the web's storage-budget warning is dropped;
/// the row/string caps remain to guard against corrupt or malicious import files.
enum Limits {
    static let maxImportBytes    = 8 * 1024 * 1024   // 8 MB
    static let maxArmies         = 500
    static let maxPaints         = 5_000
    static let maxUnitsPerArmy   = 500
    static let maxUnitsTotal     = 10_000
    static let maxStringLen      = 500
    static let maxNotesLen       = 2_000
    static let maxSquadMembers   = 99
    static let maxPipelineStages = 30
    static let maxPhotosPerUnit   = 24
    static let maxPhotoBytes      = 4 * 1024 * 1024
    static let maxPhotoDimension  = 2048
    static let jpegQuality: CGFloat = 0.82
    static let maxRosters           = 64
    static let maxEntriesPerRoster  = 128
    static let maxRosterQty         = 99
}

extension String {
    /// Trim + clamp to a maximum length. Mirrors `capStr` in `js/data/sanitize.js`.
    func capped(_ max: Int) -> String {
        String(trimmingCharacters(in: .whitespacesAndNewlines).prefix(max))
    }
}
