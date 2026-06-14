import Foundation

/// Paints CSV import & export. Ports `js/import/muster-paints.js` and `exportPaintsCSV`.
enum PaintCSV {
    static func `import`(_ rows: [[String]]) -> ImportResult {
        let hm = HeaderMap(rows: rows, required: CSVSchema.paintRequired)
        guard hm.ok else { return .failure([hm.error ?? "Invalid header"]) }

        var warnings: [String] = []
        var parsed: [PaintDraft] = []

        for (i, r) in rows.dropFirst().enumerated() {
            let line = i + 2
            let name = hm.value(r, "name")
            if name.isEmpty { continue }
            let type = hm.value(r, "type")
            let q = Normalize.qty(hm.value(r, "quantity"))
            if let w = q.warning { warnings.append("Row \(line): \(w)") }
            parsed.append(PaintDraft(
                name: name, type: type, swatchHex: PaintType.swatchHex(for: type),
                qty: q.qty, brand: hm.value(r, "brand"), source: hm.value(r, "source"),
                notes: hm.value(r, "notes")))
        }

        if parsed.isEmpty {
            return ImportResult(ok: false, errors: ["No paint rows found"], warnings: warnings,
                                stats: [:], armies: nil, paints: nil)
        }

        // Merge duplicates by lowercased name.
        var orderKeys: [String] = []
        var merged: [String: PaintDraft] = [:]
        for p in parsed {
            let k = p.name.lowercased()
            if var prev = merged[k] {
                prev.qty += p.qty
                if prev.notes.isEmpty && !p.notes.isEmpty { prev.notes = p.notes }
                merged[k] = prev
                warnings.append("Merged duplicate paint \"\(p.name)\"")
            } else {
                merged[k] = p
                orderKeys.append(k)
            }
        }
        let out = orderKeys.compactMap { merged[$0] }
        return ImportResult(ok: true, errors: [], warnings: warnings,
                            stats: ["paints": out.count], armies: nil, paints: out)
    }

    @MainActor
    static func exportRows(_ paints: [Paint]) -> [[String]] {
        var rows: [[String]] = [CSVSchema.paintExportHeaders]
        for p in paints.sorted(by: { $0.name < $1.name }) {
            rows.append([p.name, p.type, p.brand, p.source, String(p.qty), p.notes])
        }
        return rows
    }
}
