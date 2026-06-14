import Foundation
import SwiftData

/// Encodes the current store to a web-compatible JSON backup, and restores a sanitized
/// backup into the context. Ports `exportSnapshot` / `importSnapshot` (`js/core/store.js`).
@MainActor
enum BackupCodec {

    /// Build the pretty-printed JSON backup string for the current state.
    static func export(_ ctx: ModelContext) -> String {
        let armies = ((try? ctx.fetch(FetchDescriptor<Army>())) ?? []).sorted { $0.sortIndex < $1.sortIndex }
        let paints = ((try? ctx.fetch(FetchDescriptor<Paint>())) ?? []).sorted { $0.name < $1.name }
        let cfg = Config.current(ctx)
        let overrides = cfg.factionOverrides

        let collection: [ArmyDTO] = armies.map { a in
            let pres = a.presentation(overrides: overrides)
            return ArmyDTO(
                army: a.name, game: a.game, faction: a.faction,
                crest: pres.crest, color: pres.colorHex,
                crestOverride: a.crestOverride, colorOverride: a.colorOverrideHex,
                pipeline: a.customPipeline,
                units: a.orderedUnits.map { u in
                    UnitDTO(unit: u.name, qty: u.qty, source: u.source, state: u.state,
                            spearhead: u.spearhead, notes: u.notes,
                            members: u.hasSquadMembers
                                ? u.orderedMembers.map { MemberDTO(state: $0.state, notes: $0.notes) }
                                : nil)
                })
        }

        let paintDTOs: [PaintDTO] = paints.map {
            PaintDTO(name: $0.name, type: $0.type, swatch: $0.swatchHex, qty: $0.qty,
                     brand: $0.brand, source: $0.source, notes: $0.notes, low: $0.low ? true : nil)
        }

        var presets: [String: [String]]? = nil
        if !overrides.isEmpty {
            presets = Dictionary(overrides.map { ($0.key, [$0.crest, $0.hex]) }, uniquingKeysWith: { _, b in b })
        }

        let settings = SettingsDTO(
            theme: cfg.themeRaw,
            pipeline: cfg.globalPipeline,
            factionPresets: presets,
            collapsedArmies: armies.filter(\.isCollapsed).map(\.name),
            gameFilter: cfg.gameFilter, factionFilter: cfg.factionFilter,
            stateFilter: cfg.stateFilter, sourceFilter: cfg.sourceFilter,
            spearheadOnly: cfg.spearheadOnly,
            armySort: cfg.armySortRaw == "import" ? "csv" : cfg.armySortRaw,  // web uses "csv"
            unitSort: cfg.unitSortRaw, quickView: cfg.quickViewRaw, tagFilter: cfg.tagFilter,
            lastBackupAt: cfg.lastBackupAt.map { ISO8601DateFormatter().string(from: $0) })

        let snapshot = Snapshot(version: Snapshot.backupVersion, collection: collection,
                                paints: paintDTOs, settings: settings,
                                exportedAt: ISO8601DateFormatter().string(from: Date()))

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(snapshot), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    /// Replace all data with a sanitized backup. Mirrors `importSnapshot`.
    static func restore(_ backup: SanitizedBackup, into ctx: ModelContext) {
        // Wipe everything (incl. config) then rebuild.
        for a in (try? ctx.fetch(FetchDescriptor<Army>())) ?? [] { ctx.delete(a) }
        for p in (try? ctx.fetch(FetchDescriptor<Paint>())) ?? [] { ctx.delete(p) }
        for c in (try? ctx.fetch(FetchDescriptor<AppConfiguration>())) ?? [] { ctx.delete(c) }

        CollectionStore.replaceArmies(backup.armies, in: ctx)
        CollectionStore.replacePaints(backup.paints, in: ctx)

        let cfg = AppConfiguration()
        let s = backup.settings
        cfg.theme = s.theme
        cfg.globalPipeline = s.globalPipeline
        cfg.factionOverrides = s.factionOverrides
        cfg.gameFilter = s.gameFilter
        cfg.factionFilter = s.factionFilter
        cfg.stateFilter = s.stateFilter
        cfg.sourceFilter = s.sourceFilter
        cfg.tagFilter = s.tagFilter
        cfg.spearheadOnly = s.spearheadOnly
        cfg.quickViewRaw = s.quickView
        cfg.armySortRaw = s.armySort
        cfg.unitSortRaw = s.unitSort
        cfg.lastBackupAt = s.lastBackupAt
        ctx.insert(cfg)
        try? ctx.save()
    }
}
