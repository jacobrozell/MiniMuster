import Foundation
import SwiftData

/// Paint CRUD. Ports `addPaint`, `updatePaint`, `removePaint` (`js/core/store.js`) and the
/// add/edit flows (`js/render/paints.js`). Name uniqueness is case-insensitive.
@MainActor
enum PaintStore {

    @discardableResult
    static func add(name: String, type: String, brand: String, source: String,
                    qty: Int, notes: String, low: Bool, in ctx: ModelContext) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let all = (try? ctx.fetch(FetchDescriptor<Paint>())) ?? []
        guard !all.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else { return false }
        let p = Paint(name: trimmed.capped(Limits.maxStringLen), type: type,
                      swatchHex: PaintType.swatchHex(for: type), qty: max(1, qty),
                      brand: brand.capped(Limits.maxStringLen), source: source.capped(Limits.maxStringLen),
                      notes: notes.capped(Limits.maxNotesLen), low: low)
        ctx.insert(p)
        try? ctx.save()
        return true
    }

    @discardableResult
    static func update(_ paint: Paint, name: String, type: String, brand: String, source: String,
                       qty: Int, notes: String, low: Bool, in ctx: ModelContext) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let all = (try? ctx.fetch(FetchDescriptor<Paint>())) ?? []
        if all.contains(where: { $0 !== paint && $0.name.lowercased() == trimmed.lowercased() }) {
            return false
        }
        paint.name = trimmed.capped(Limits.maxStringLen)
        paint.type = type
        paint.swatchHex = PaintType.swatchHex(for: type)
        paint.brand = brand.capped(Limits.maxStringLen)
        paint.source = source.capped(Limits.maxStringLen)
        paint.qty = max(1, min(9999, qty))
        paint.notes = notes.capped(Limits.maxNotesLen)
        paint.low = low
        try? ctx.save()
        return true
    }

    static func delete(_ paint: Paint, in ctx: ModelContext) {
        ctx.delete(paint)
        try? ctx.save()
    }

    /// Number of units across all armies whose source fuzzily matches this paint's source.
    /// Mirrors `unitsForSource`.
    static func linkedUnitCount(source: String, armies: [Army]) -> Int {
        guard !source.isEmpty else { return 0 }
        return armies.reduce(0) { acc, a in
            acc + a.units.filter { SourceMatch.matches(source, $0.source) }.count
        }
    }
}
