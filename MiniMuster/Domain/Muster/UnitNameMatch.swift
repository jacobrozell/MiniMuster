import Foundation

enum UnitNameMatch {
    /// Normalize for comparison: lowercase, collapse whitespace, strip first "(...)" group.
    static func normalize(_ name: String) -> String {
        var s = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let inner = ModelCount.firstParenGroup(name) {
            s = s.replacingOccurrences(of: "(\(inner))", with: "")
        }
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// True if collection unit name matches catalog entry name or any alias.
    static func matches(collectionUnitName: String, catalogName: String, aliases: [String]) -> Bool {
        let c = normalize(collectionUnitName)
        guard !c.isEmpty else { return false }
        let candidates = [catalogName] + aliases
        for raw in candidates {
            let n = normalize(raw)
            if c == n { return true }
            if c.contains(n) || n.contains(c) { return true }
        }
        return false
    }
}
