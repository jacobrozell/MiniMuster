import Foundation
import SwiftData

/// One army plus its filtered+sorted visible units.
struct VisibleArmy: Identifiable {
    let army: Army
    let units: [Unit]
    var id: PersistentIdentifier { army.persistentModelID }
}

/// The Armies-tab filtering/sorting pipeline. Ports `visibleArmies`, `unitPassesFilters`,
/// `unitMatchesSearch`, `sortArmies`, `sortUnitEntries`, `filtersActive`
/// (`js/render/armies.js`). See `docs/ios-spec/06-filters-search-sort.md`.
@MainActor
enum ArmyFilter {

    static func isActive(_ cfg: AppConfiguration, search: String) -> Bool {
        cfg.gameFilter != "All" || cfg.factionFilter != "All" || !search.isEmpty
            || cfg.stateFilter != "All" || cfg.sourceFilter != "All" || cfg.spearheadOnly
            || cfg.quickViewRaw != "all" || cfg.tagFilter != "All"
    }

    static func build(armies: [Army], cfg: AppConfiguration, search: String,
                      global: [PipelineStage]?) -> [VisibleArmy] {
        let q = search.lowercased()
        let active = isActive(cfg, search: search)

        let result: [VisibleArmy] = armies
            .filter { (cfg.gameFilter == "All" || $0.game == cfg.gameFilter)
                && (cfg.factionFilter == "All" || $0.faction == cfg.factionFilter) }
            .map { army in
                let pipeline = Pipeline.forArmy(army, global: global)
                var units = army.orderedUnits
                if !q.isEmpty { units = units.filter { matchesSearch($0, army: army.name, q: q) } }
                units = units.filter { passesFilters($0, pipeline: pipeline, cfg: cfg) }
                units = sortUnits(units, cfg: cfg, global: global)
                return VisibleArmy(army: army, units: units)
            }
            .filter { active ? !$0.units.isEmpty : true }

        return sortArmies(result, cfg: cfg, global: global)
    }

    // MARK: Predicates

    static func matchesSearch(_ u: Unit, army: String, q: String) -> Bool {
        let memberHay = u.hasSquadMembers
            ? u.orderedMembers.map { "\($0.state ?? "") \($0.notes ?? "")" }.joined(separator: " ")
            : ""
        let hay = "\(u.name) \(u.source) \(u.state) \(u.notes) \(memberHay) \(army)".lowercased()
        return hay.contains(q)
    }

    static func passesFilters(_ u: Unit, pipeline: [PipelineStage], cfg: AppConfiguration) -> Bool {
        if !Members.unitMatchesStateFilter(u, cfg.stateFilter) { return false }
        if cfg.sourceFilter != "All", u.source != cfg.sourceFilter { return false }
        if cfg.spearheadOnly, u.spearhead != true { return false }
        if cfg.tagFilter != "All", !Tags.extract(u.notes).contains(cfg.tagFilter) { return false }
        if !Members.unitPassesQuickView(u, pipeline: pipeline, quickView: cfg.quickViewRaw) { return false }
        return true
    }

    // MARK: Sorting

    static func sortUnits(_ units: [Unit], cfg: AppConfiguration, global: [PipelineStage]?) -> [Unit] {
        if cfg.unitSortRaw == "state" {
            let pipeline = Pipeline.resolve(global)
            let idx = Dictionary(uniqueKeysWithValues: pipeline.enumerated().map { ($1.key, $0) })
            return units.sorted {
                let a = idx[$0.state] ?? 0, b = idx[$1.state] ?? 0
                return a != b ? a < b : $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
        return units.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func sortArmies(_ armies: [VisibleArmy], cfg: AppConfiguration, global: [PipelineStage]?) -> [VisibleArmy] {
        switch cfg.armySortRaw {
        case "name":
            return armies.sorted { $0.army.name.localizedStandardCompare($1.army.name) == .orderedAscending }
        case "progress":
            return armies.sorted {
                Pipeline.progress(of: $0.army.units, Pipeline.forArmy($0.army, global: global))
                    < Pipeline.progress(of: $1.army.units, Pipeline.forArmy($1.army, global: global))
            }
        default: // "import"
            return armies.sorted { $0.army.sortIndex < $1.army.sortIndex }
        }
    }

    // MARK: Filter option sources

    static func allNoteTags(_ armies: [Army]) -> [String] {
        var set = Set<String>()
        for a in armies { for u in a.units { for t in Tags.extract(u.notes) { set.insert(t) } } }
        return set.sorted()
    }

    static func allSources(_ armies: [Army]) -> [String] {
        var set = Set<String>()
        for a in armies { for u in a.units where !u.source.isEmpty { set.insert(u.source) } }
        return set.sorted()
    }

    static func clearFilters(_ cfg: AppConfiguration) {
        cfg.gameFilter = "All"; cfg.factionFilter = "All"; cfg.stateFilter = "All"
        cfg.sourceFilter = "All"; cfg.tagFilter = "All"; cfg.spearheadOnly = false
        cfg.quickViewRaw = "all"
    }

    /// Count of non-default filter prefs (excludes search text).
    static func activeFilterCount(_ cfg: AppConfiguration) -> Int {
        var n = 0
        if cfg.gameFilter != "All" { n += 1 }
        if cfg.factionFilter != "All" { n += 1 }
        if cfg.stateFilter != "All" { n += 1 }
        if cfg.sourceFilter != "All" { n += 1 }
        if cfg.tagFilter != "All" { n += 1 }
        if cfg.spearheadOnly { n += 1 }
        if cfg.quickViewRaw != "all" { n += 1 }
        return n
    }
}
