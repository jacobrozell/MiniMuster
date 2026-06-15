import Foundation

/// Estimated physical model count for a unit entry. Ports `modelCount` from
/// `js/core/members.js`: sum of all integer groups inside the FIRST `(...)` in the name,
/// times qty. No parentheses, or no digits inside → qty (min 1).
///
///   "Clanrats (5)" qty 2 → 10
///   "Reclusians + Memorians (x3 + x2)" qty 1 → 5
///   "Lord-Vigilant" qty 3 → 3
enum ModelCount {
    static func of(name: String, qty: Int) -> Int {
        let q = max(1, qty)
        guard let inner = firstParenGroup(name) else { return q }
        let nums = inner.matches(of: /\d+/).compactMap { Int($0.output) }
        guard !nums.isEmpty else { return q }
        return nums.reduce(0, +) * q
    }

    /// Contents of the first `(...)` group, or nil if there isn't a closed one.
    /// Mirrors the JS regex `/\(([^)]*)\)/`.
    static func firstParenGroup(_ name: String) -> Substring? {
        guard let open = name.firstIndex(of: "(") else { return nil }
        let afterOpen = name.index(after: open)
        guard let close = name[afterOpen...].firstIndex(of: ")") else { return nil }
        return name[afterOpen..<close]
    }
}
