import Foundation
import SwiftData

/// Paint-tab filtering and search. Mirrors the predicates in `PaintListView`.
@MainActor
enum PaintFilter {

    static func isActive(_ cfg: AppConfiguration, search: String) -> Bool {
        cfg.paintTypeFilter != "All" || cfg.paintBrandFilter != "All" || cfg.paintLowOnly || !search.isEmpty
    }

    static func activeFilterCount(_ cfg: AppConfiguration) -> Int {
        var count = 0
        if cfg.paintTypeFilter != "All" { count += 1 }
        if cfg.paintBrandFilter != "All" { count += 1 }
        if cfg.paintLowOnly { count += 1 }
        return count
    }

    static func clearFilters(_ cfg: AppConfiguration) {
        cfg.paintTypeFilter = "All"
        cfg.paintBrandFilter = "All"
        cfg.paintLowOnly = false
    }

    static func filter(_ paints: [Paint], cfg: AppConfiguration, search: String) -> [Paint] {
        let q = search.lowercased()
        return paints.filter { p in
            (!cfg.paintLowOnly || p.low)
            && (cfg.paintTypeFilter == "All" || p.type == cfg.paintTypeFilter)
            && (cfg.paintBrandFilter == "All" || p.brand == cfg.paintBrandFilter)
            && (q.isEmpty || "\(p.name) \(p.type) \(p.brand) \(p.source) \(p.notes)".lowercased().contains(q))
        }
    }
}
