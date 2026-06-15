import Foundation

/// CSV parsing & writing. Ports `parseCSV`, `serializeCSV`, `escapeCSV`, `detectDelimiter`
/// from `js/data/csv.js`, including the hand-rolled RFC-4180 state machine.
enum CSV {
    /// Auto-detect the delimiter from the first line (tab / semicolon / comma).
    static func detectDelimiter(_ text: String) -> Character {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let tabs = line.filter { $0 == "\t" }.count
        let semis = line.filter { $0 == ";" }.count
        let commas = line.filter { $0 == "," }.count
        if tabs > commas && tabs > semis { return "\t" }
        if semis > commas { return ";" }
        return ","
    }

    /// Parse CSV text into rows of fields. Strips a leading BOM, normalizes the delimiter to
    /// comma, handles quoted fields with doubled-quote escapes, and drops all-blank rows.
    static func parse(_ rawText: String) -> [[String]] {
        var text = rawText
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // Normalize non-comma delimiters by re-quoting, matching the JS preprocessing.
        let delim = detectDelimiter(text)
        if delim != "," {
            text = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
                line.split(separator: delim, omittingEmptySubsequences: false).map { part in
                    let p = String(part)
                    return p.contains(where: { $0 == "\"" || $0 == "," || $0 == "\n" })
                        ? "\"\(p.replacingOccurrences(of: "\"", with: "\"\""))\""
                        : p
                }.joined(separator: ",")
            }.joined(separator: "\n")
        }

        var rows: [[String]] = []
        var row: [String] = []
        var cur = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if inQuotes {
                if ch == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { cur.append("\""); i += 1 }
                    else { inQuotes = false }
                } else { cur.append(ch) }
            } else if ch == "\"" {
                inQuotes = true
            } else if ch == "," {
                row.append(cur); cur = ""
            } else if ch == "\n" {
                row.append(cur); rows.append(row); row = []; cur = ""
            } else if ch != "\r" {
                cur.append(ch)
            }
            i += 1
        }
        if !cur.isEmpty || !row.isEmpty { row.append(cur); rows.append(row) }

        return rows.filter { r in r.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }

    /// Quote a field if it contains a comma, quote, or newline.
    static func escapeField(_ value: String) -> String {
        value.contains(where: { $0 == "\"" || $0 == "," || $0 == "\n" })
            ? "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
            : value
    }

    static func serialize(_ rows: [[String]]) -> String {
        rows.map { $0.map(escapeField).joined(separator: ",") }.joined(separator: "\n")
    }
}
