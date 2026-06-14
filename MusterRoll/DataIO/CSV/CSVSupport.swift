import Foundation

/// Header lookup + field normalizers. Ports `headerMap`, `normalizeQty`, `normalizeBool`,
/// `fileImportHint` from `js/data/csv.js`.

/// Column index lookup over a header row (lowercased/trimmed).
struct HeaderMap {
    let ok: Bool
    let error: String?
    private let index: [String: Int]

    init(rows: [[String]], required: [String]) {
        guard let head = rows.first else {
            ok = false; error = "File is empty"; index = [:]; return
        }
        var idx: [String: Int] = [:]
        for (i, h) in head.enumerated() {
            idx[h.trimmingCharacters(in: .whitespaces).lowercased()] = i
        }
        index = idx
        let missing = required.filter { idx[$0] == nil }
        if missing.isEmpty {
            ok = true; error = nil
        } else {
            ok = false; error = "Missing required columns: \(missing.joined(separator: ", "))"
        }
    }

    /// Column index for a header name, or -1.
    func col(_ name: String) -> Int { index[name] ?? -1 }

    /// Trimmed value at a column for a row, or "".
    func value(_ row: [String], _ name: String) -> String {
        let c = col(name)
        guard c >= 0, c < row.count else { return "" }
        return row[c].trimmingCharacters(in: .whitespaces)
    }
}

enum Normalize {
    struct QtyResult { let qty: Int; let warning: String? }

    /// Mirrors `normalizeQty`: empty → default; non-integer/negative → default + warning;
    /// 0 → default + "cannot be 0" warning.
    static func qty(_ raw: String, default def: Int = 1) -> QtyResult {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return QtyResult(qty: def, warning: nil) }
        guard let n = Int(s), n >= 0 else {
            return QtyResult(qty: def, warning: "Invalid Qty \"\(raw)\" — using \(def)")
        }
        if n == 0 && def > 0 {
            return QtyResult(qty: def, warning: "Qty cannot be 0 — using \(def)")
        }
        return QtyResult(qty: n, warning: nil)
    }

    struct BoolResult { let value: Bool?; let warning: String? }

    /// Mirrors `normalizeBool`.
    static func bool(_ raw: String) -> BoolResult {
        let s = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if s.isEmpty { return BoolResult(value: nil, warning: nil) }
        if ["yes", "y", "true", "1"].contains(s) { return BoolResult(value: true, warning: nil) }
        if ["no", "n", "false", "0"].contains(s) { return BoolResult(value: false, warning: nil) }
        return BoolResult(value: nil, warning: "Unrecognised boolean value \"\(raw)\" — ignored")
    }
}

/// `.xlsx`/`.xls` guidance. Mirrors `fileImportHint`.
func fileImportHint(_ name: String) -> String? {
    let lower = name.lowercased()
    if lower.hasSuffix(".xlsx") || lower.hasSuffix(".xls") {
        return "Excel (.xlsx) files are not supported — open in Excel and Save As CSV (UTF-8)."
    }
    return nil
}
