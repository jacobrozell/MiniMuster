import Foundation

/// CSV schemas, detection, export headers, and templates. Ports `js/data/schema.js` and the
/// `ARMY_SCHEMA` / `PAINT_SCHEMA` export headers + templates.
enum CSVSchema {
    enum Domain { case armies, paints }

    static let armyRequired = ["game", "faction", "army", "unit"]
    static let paintRequired = ["name"]

    static let armyExportHeaders = [
        "Game", "Faction", "Army", "Unit", "Qty", "Source", "State", "Spearhead",
        "Notes", "Member", "MemberState", "MemberNotes", "Crest", "Color",
    ]
    static let paintExportHeaders = ["Name", "Type", "Brand", "Source", "Quantity", "Notes"]

    static let armyTemplate =
        "Game,Faction,Army,Unit,Qty,Source,State,Spearhead,Notes,Crest,Color\n" +
        "40k,Space Marines,My Chapter,Intercessors (5),1,Starter Set,Unassembled,,,SM,#1c4fa0\n"
    static let paintTemplate =
        "Name,Type,Brand,Source,Quantity,Notes\nMacragge Blue,Base,Citadel,Paint Set,1,\n"

    static func template(_ domain: Domain) -> String {
        domain == .armies ? armyTemplate : paintTemplate
    }

    static func filename(_ domain: Domain) -> String {
        domain == .armies ? "warhammer_armies.csv" : "warhammer_paint_inventory.csv"
    }

    /// Header-row detection. Mirrors `detectMusterArmies` / `detectMusterPaints`.
    static func detect(_ rows: [[String]]) -> Domain? {
        let head = (rows.first ?? []).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let set = Set(head)
        if ["game", "army", "unit"].allSatisfy(set.contains) { return .armies }
        if set.contains("name") { return .paints }
        return nil
    }
}
