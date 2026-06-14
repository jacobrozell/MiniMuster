import Foundation

/// Armies CSV import & export. Ports `js/import/muster-armies.js` and the army half of
/// `exportArmiesCSV` (`js/import/index.js`).
enum ArmyCSV {

    /// Squad grouping key — units merge member rows when these match. Ports `squadGroupKey`.
    private static func squadGroupKey(_ a: UnitDraft, _ b: UnitDraft) -> Bool {
        func spear(_ u: UnitDraft) -> String { u.spearhead.map(String.init) ?? "" }
        return a.name == b.name
            && a.source == b.source
            && a.qty == b.qty
            && spear(a) == spear(b)
    }

    /// Ensure a draft has at least `n` members (padding with inheriting members).
    private static func ensureMembers(_ unit: inout UnitDraft, count n: Int) {
        guard n >= 2 else { return }
        while unit.members.count < n { unit.members.append(MemberDraft()) }
        if unit.members.count > n { unit.members.removeLast(unit.members.count - n) }
    }

    /// Import armies. `pipeline` is the active (global) pipeline used to normalize states.
    static func `import`(_ rows: [[String]],
                         pipeline: [PipelineStage],
                         overrides: [FactionPresetOverride]) -> ImportResult {
        let hm = HeaderMap(rows: rows, required: CSVSchema.armyRequired)
        guard hm.ok else { return .failure([hm.error ?? "Invalid header"]) }

        var errors: [String] = []
        var warnings: [String] = []
        var order: [String] = []
        var map: [String: ArmyDraft] = [:]
        // crest/colour captured from the first row of each army group
        var csvCrest: [String: String] = [:]
        var csvColor: [String: String] = [:]

        let hasMember = hm.col("member") >= 0
        let hasMemberState = hm.col("memberstate") >= 0
        let hasMemberNotes = hm.col("membernotes") >= 0

        for (i, r) in rows.dropFirst().enumerated() {
            let line = i + 2
            let army = hm.value(r, "army")
            let unit = hm.value(r, "unit")
            if army.isEmpty && unit.isEmpty { continue }
            if army.isEmpty { errors.append("Row \(line): missing Army"); continue }
            if unit.isEmpty { errors.append("Row \(line): missing Unit"); continue }

            let game = hm.value(r, "game")
            let faction = hm.value(r, "faction")
            if game.isEmpty { warnings.append("Row \(line): missing Game") }
            if faction.isEmpty { warnings.append("Row \(line): missing Faction") }

            if map[army] == nil {
                map[army] = ArmyDraft(name: army, game: game, faction: faction)
                order.append(army)
                if hm.col("crest") >= 0 {
                    let c = hm.value(r, "crest"); if !c.isEmpty { csvCrest[army] = String(c.prefix(8)) }
                }
                if hm.col("color") >= 0 {
                    let c = hm.value(r, "color"); if !c.isEmpty { csvColor[army] = c }
                }
            } else {
                if !game.isEmpty, !map[army]!.game.isEmpty, map[army]!.game != game {
                    warnings.append("Row \(line): Game \"\(game)\" differs from first row for army \"\(army)\"")
                }
                if !faction.isEmpty, !map[army]!.faction.isEmpty, map[army]!.faction != faction {
                    warnings.append("Row \(line): Faction \"\(faction)\" differs from first row for army \"\(army)\"")
                }
            }

            let q = Normalize.qty(hm.value(r, "qty"))
            if let w = q.warning { warnings.append("Row \(line): \(w)") }
            let st = Pipeline.normalizeState(hm.value(r, "state"), pipeline: pipeline)
            if let w = st.warning { warnings.append("Row \(line): \(w)") }

            var u = UnitDraft(name: unit, qty: q.qty, source: hm.value(r, "source"), state: st.state)
            let sp = Normalize.bool(hm.value(r, "spearhead"))
            if let w = sp.warning { warnings.append("Row \(line): \(w)") }
            u.spearhead = sp.value
            u.notes = hm.value(r, "notes")

            // Member handling.
            let memberRaw = hasMember ? hm.value(r, "member") : ""
            if hasMember && !memberRaw.isEmpty {
                guard let memberNum = Int(memberRaw), memberNum >= 1 else {
                    warnings.append("Row \(line): invalid Member \"\(memberRaw)\" — skipping member data")
                    map[army]!.units.append(u)
                    continue
                }
                // Find an existing matching unit to attach this member to.
                if let idx = map[army]!.units.firstIndex(where: { squadGroupKey($0, u) }) {
                    var existing = map[army]!.units[idx]
                    let size = ModelCount.of(name: existing.name, qty: existing.qty)
                    ensureMembers(&existing, count: size)
                    if memberNum > size {
                        warnings.append("Row \(line): Member \(memberNum) exceeds squad size (\(size))")
                    } else {
                        applyMember(&existing, memberNum - 1, row: r, hm: hm, line: line,
                                    pipeline: pipeline, warnings: &warnings,
                                    hasMemberState: hasMemberState, hasMemberNotes: hasMemberNotes)
                    }
                    map[army]!.units[idx] = existing
                } else {
                    let size = ModelCount.of(name: u.name, qty: u.qty)
                    ensureMembers(&u, count: size)
                    if memberNum > size {
                        warnings.append("Row \(line): Member \(memberNum) exceeds squad size (\(size))")
                    } else {
                        applyMember(&u, memberNum - 1, row: r, hm: hm, line: line,
                                    pipeline: pipeline, warnings: &warnings,
                                    hasMemberState: hasMemberState, hasMemberNotes: hasMemberNotes)
                    }
                    map[army]!.units.append(u)
                }
                continue
            }

            map[army]!.units.append(u)
        }

        if order.isEmpty { errors.append("No unit rows found") }
        if !errors.isEmpty { return ImportResult(ok: false, errors: errors, warnings: warnings, stats: [:], armies: nil, paints: nil) }

        var warnedFactions = Set<String>()
        var armies: [ArmyDraft] = []
        for name in order {
            var a = map[name]!
            let resolved = FactionResolver.resolve(faction: a.faction, game: a.game, overrides: overrides)
            let key = "\(a.game)\u{0}\(a.faction)"
            if !a.faction.isEmpty, FactionResolver.isFallback(resolved.color), !warnedFactions.contains(key) {
                warnedFactions.insert(key)
                let scope = a.game.isEmpty ? "" : " for game \"\(a.game)\""
                warnings.append("Unknown faction \"\(a.faction)\"\(scope) — using default grey crest")
            }
            if let crest = csvCrest[name] { a.crestOverride = crest }
            if let color = csvColor[name] {
                if color.wholeMatch(of: /#[0-9a-fA-F]{3,8}/) == nil {
                    warnings.append("Army \"\(name)\": invalid Color \"\(color)\" — using preset")
                } else {
                    a.colorOverrideHex = safeColor(color)
                }
            }
            armies.append(a)
        }

        let unitCount = armies.reduce(0) { $0 + $1.units.count }
        return ImportResult(ok: true, errors: [], warnings: warnings,
                            stats: ["armies": armies.count, "units": unitCount],
                            armies: armies, paints: nil)
    }

    private static func applyMember(_ unit: inout UnitDraft, _ index: Int, row r: [String],
                                    hm: HeaderMap, line: Int, pipeline: [PipelineStage],
                                    warnings: inout [String],
                                    hasMemberState: Bool, hasMemberNotes: Bool) {
        guard index >= 0, index < unit.members.count else { return }
        var m = unit.members[index]
        if hasMemberState {
            let raw = hm.value(r, "memberstate")
            if !raw.isEmpty {
                let ms = Pipeline.normalizeState(raw, pipeline: pipeline)
                if let w = ms.warning { warnings.append("Row \(line): \(w)") }
                m.state = ms.state
            }
        }
        if hasMemberNotes {
            let mn = hm.value(r, "membernotes")
            if !mn.isEmpty { m.notes = mn }
        }
        unit.members[index] = m
    }

    // MARK: Export

    /// Build CSV rows for export. One row per unit, or one row per member when present.
    /// Ports `exportArmiesCSV`.
    @MainActor
    static func exportRows(_ armies: [Army], overrides: [FactionPresetOverride]) -> [[String]] {
        var rows: [[String]] = [CSVSchema.armyExportHeaders]
        for a in armies.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            let pres = a.presentation(overrides: overrides)
            for u in a.orderedUnits {
                let base: [String] = [
                    a.game, a.faction, a.name, u.name, String(u.qty), u.source, u.state,
                    u.spearhead.map { $0 ? "Yes" : "No" } ?? "", u.notes,
                ]
                if u.hasSquadMembers {
                    for m in u.orderedMembers {
                        rows.append(base + [String(m.index + 1), m.state ?? "", m.notes ?? "",
                                            pres.crest, pres.colorHex])
                    }
                } else {
                    rows.append(base + ["", "", "", pres.crest, pres.colorHex])
                }
            }
        }
        return rows
    }
}
