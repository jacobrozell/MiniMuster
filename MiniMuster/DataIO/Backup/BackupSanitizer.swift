import Foundation

/// Sanitized restore payload: drafts + settings + a human preview.
struct SanitizedBackup: Sendable {
    var armies: [ArmyDraft]
    var paints: [PaintDraft]
    var settings: SanitizedSettings
    var preview: String
}

/// Subset of settings restored from a backup. Applied to `AppConfiguration` on restore.
struct SanitizedSettings: Sendable {
    var theme: ThemePreference = .system
    var globalPipeline: [PipelineStage]? = nil
    var factionOverrides: [FactionPresetOverride] = []
    var gameFilter = "All"
    var factionFilter = "All"
    var stateFilter = "All"
    var sourceFilter = "All"
    var tagFilter = "All"
    var spearheadOnly = false
    var quickView = "all"
    var armySort = "import"   // mapped from web "csv"
    var unitSort = "name"
    var lastBackupAt: Date?
}

enum BackupError: Error, Equatable {
    case tooLarge(maxMB: Int)
    case invalidJSON
    case notObject
    case unknownKeys([String])
    case overLimit(String)

    var message: String {
        switch self {
        case .tooLarge(let mb): "File exceeds \(mb) MB limit"
        case .invalidJSON: "Invalid JSON"
        case .notObject: "Backup must be a JSON object"
        case .unknownKeys(let k): "Unknown backup fields: \(k.joined(separator: ", "))"
        case .overLimit(let m): m
        }
    }
}

/// Validates + sanitizes a JSON backup. Ports `parseBackup` / `sanitizeAppState` from
/// `js/data/sanitize.js`. This is the primary untrusted-input boundary.
enum BackupSanitizer {

    static func parse(_ json: String, byteLength: Int? = nil) -> Result<SanitizedBackup, BackupError> {
        let size = byteLength ?? json.utf8.count
        if size > Limits.maxImportBytes {
            return .failure(.tooLarge(maxMB: Limits.maxImportBytes / (1024 * 1024)))
        }
        guard let data = json.data(using: .utf8) else { return .failure(.invalidJSON) }

        // Top-level object + strict-keys check via JSONSerialization.
        let object: [String: Any]
        do {
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failure(.notObject)
            }
            object = obj
        } catch {
            return .failure(.invalidJSON)
        }
        let extra = object.keys.filter { !Snapshot.allowedKeys.contains($0) }
        if !extra.isEmpty { return .failure(.unknownKeys(extra.sorted())) }

        let snapshot: Snapshot
        do {
            snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
        } catch {
            return .failure(.invalidJSON)
        }
        return sanitize(snapshot)
    }

    static func sanitize(_ s: Snapshot) -> Result<SanitizedBackup, BackupError> {
        // Enforce caps before mapping.
        let collection = s.collection ?? []
        if collection.count > Limits.maxArmies {
            return .failure(.overLimit("Too many armies (max \(Limits.maxArmies))"))
        }
        var totalUnits = 0
        for a in collection {
            let count = a.units?.count ?? 0
            if count > Limits.maxUnitsPerArmy {
                return .failure(.overLimit("Army \"\(a.army ?? "unknown")\" exceeds \(Limits.maxUnitsPerArmy) unit entries"))
            }
            totalUnits += count
            if totalUnits > Limits.maxUnitsTotal {
                return .failure(.overLimit("Too many unit entries (max \(Limits.maxUnitsTotal))"))
            }
        }
        if (s.paints?.count ?? 0) > Limits.maxPaints {
            return .failure(.overLimit("Too many paints (max \(Limits.maxPaints))"))
        }

        let armies: [ArmyDraft] = collection.prefix(Limits.maxArmies).compactMap { dto in
            let name = (dto.army ?? "").capped(Limits.maxStringLen)
            guard !name.isEmpty else { return nil }
            var draft = ArmyDraft(name: name,
                                  game: (dto.game ?? "").capped(Limits.maxStringLen),
                                  faction: (dto.faction ?? "").capped(Limits.maxStringLen))
            if let c = dto.crestOverride, !c.isEmpty { draft.crestOverride = String(c.prefix(8)) }
            if let c = dto.colorOverride, !c.isEmpty { draft.colorOverrideHex = safeColor(c) }
            if let pipe = sanitizePipeline(dto.pipeline) { draft.customPipeline = pipe }
            draft.units = (dto.units ?? []).prefix(Limits.maxUnitsPerArmy).map { u in
                var ud = UnitDraft(name: (u.unit ?? "").capped(Limits.maxStringLen),
                                   qty: max(1, min(9999, u.qty ?? 1)),
                                   source: (u.source ?? "").capped(Limits.maxStringLen),
                                   state: (u.state ?? "").capped(Limits.maxStringLen),
                                   notes: (u.notes ?? "").capped(Limits.maxNotesLen))
                ud.spearhead = u.spearhead
                if let members = u.members, !members.isEmpty {
                    ud.members = members.prefix(Limits.maxSquadMembers).map { m in
                        MemberDraft(
                            state: (m.state?.capped(Limits.maxStringLen)).flatMap { $0.isEmpty ? nil : $0 },
                            notes: (m.notes?.capped(Limits.maxNotesLen)).flatMap { $0.isEmpty ? nil : $0 })
                    }
                }
                return ud
            }
            return draft
        }

        let paints: [PaintDraft] = (s.paints ?? []).prefix(Limits.maxPaints).compactMap { dto in
            let name = (dto.name ?? "").capped(Limits.maxStringLen)
            guard !name.isEmpty else { return nil }
            return PaintDraft(name: name,
                              type: (dto.type ?? "").capped(Limits.maxStringLen),
                              swatchHex: safeColor(dto.swatch),
                              qty: max(1, min(9999, dto.qty ?? 1)),
                              brand: (dto.brand ?? "").capped(Limits.maxStringLen),
                              source: (dto.source ?? "").capped(Limits.maxStringLen),
                              notes: (dto.notes ?? "").capped(Limits.maxNotesLen),
                              low: dto.low == true)
        }

        let settings = sanitizeSettings(s.settings)
        let preview = "\(armies.count) armies (\(armies.reduce(0) { $0 + $1.units.count }) unit entries), \(paints.count) paints"
        return .success(SanitizedBackup(armies: armies, paints: paints, settings: settings, preview: preview))
    }

    private static func sanitizePipeline(_ raw: [PipelineStage]?) -> [PipelineStage]? {
        guard let raw, !raw.isEmpty else { return nil }
        let cleaned = raw.prefix(Limits.maxPipelineStages).compactMap { s -> PipelineStage? in
            let key = s.key.capped(Limits.maxStringLen)
            return key.isEmpty ? nil : PipelineStage(key: key, hex: safeColor(s.hex))
        }
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func sanitizeSettings(_ dto: SettingsDTO?) -> SanitizedSettings {
        var out = SanitizedSettings()
        guard let dto else { return out }
        if let t = dto.theme, let pref = ThemePreference(rawValue: t) { out.theme = pref }
        out.globalPipeline = sanitizePipeline(dto.pipeline)
        if let fp = dto.factionPresets {
            out.factionOverrides = fp.compactMap { key, value in
                guard value.count >= 2 else { return nil }
                return FactionPresetOverride(key: key.capped(Limits.maxStringLen),
                                             crest: String(value[0].prefix(8)),
                                             hex: safeColor(value[1]))
            }
        }
        if let v = dto.gameFilter { out.gameFilter = v.capped(Limits.maxStringLen) }
        if let v = dto.factionFilter { out.factionFilter = v.capped(Limits.maxStringLen) }
        if let v = dto.stateFilter { out.stateFilter = v.capped(Limits.maxStringLen) }
        if let v = dto.sourceFilter { out.sourceFilter = v.capped(Limits.maxStringLen) }
        if let v = dto.tagFilter { out.tagFilter = v.capped(Limits.maxStringLen) }
        if dto.spearheadOnly == true { out.spearheadOnly = true }
        if let v = dto.quickView, ["all", "backlog", "wip", "ready"].contains(v) { out.quickView = v }
        // Map web "csv" → iOS "import".
        if let v = dto.armySort {
            let mapped = v == "csv" ? "import" : v
            if ["import", "name", "progress"].contains(mapped) { out.armySort = mapped }
        }
        if let v = dto.unitSort, ["name", "state"].contains(v) { out.unitSort = v }
        if let v = dto.lastBackupAt { out.lastBackupAt = ISO8601DateFormatter().date(from: v) }
        return out
    }
}
