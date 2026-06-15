import Foundation

enum UnitCatalogLoader {
    private(set) nonisolated(unsafe) static var manifest: UnitCatalogManifest?
    nonisolated(unsafe) private static var cache: [String: [CatalogUnit]] = [:]
    nonisolated(unsafe) private static var byId: [String: CatalogUnit] = [:]

    /// Call once from MusterTab.onAppear or app init (idempotent).
    static func loadIfNeeded() {
        guard manifest == nil else { return }
        manifest = decode("manifest", UnitCatalogManifest.self)
        let index = decode("index", UnitCatalogIndex.self)
        for (_, path) in index?.factions ?? [:] {
            let file = decodePath(path, FactionCatalogFile.self)
            let key = factionKey(game: file?.game ?? "", faction: file?.faction ?? "")
            let units = file?.units ?? []
            cache[key] = units
            for u in units { byId[u.id] = u }
        }
    }

    static var version: String { manifest?.version ?? "0" }

    static func units(game: String, faction: String) -> [CatalogUnit] {
        loadIfNeeded()
        return cache[factionKey(game: game, faction: faction)] ?? []
    }

    static func unit(id: String) -> CatalogUnit? {
        loadIfNeeded()
        return byId[id]
    }

    static func search(game: String, faction: String, query: String) -> [CatalogUnit] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let all = units(game: game, faction: faction)
        guard !q.isEmpty else { return all }
        return all.filter { u in
            u.name.lowercased().contains(q)
            || u.category.lowercased().contains(q)
            || u.keywords.contains { $0.lowercased().contains(q) }
            || u.aliases.contains { $0.lowercased().contains(q) }
        }
    }

    private static func factionKey(game: String, faction: String) -> String {
        "\(game):\(FactionResolver.normalize(faction))"
    }

    private static func decode<T: Decodable>(_ name: String, _ type: T.Type) -> T? {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "UnitCatalog"),
            Bundle.main.url(forResource: name, withExtension: "json"),
        ]
        for url in candidates.compactMap({ $0 }) {
            if let value = try? JSONDecoder().decode(T.self, from: Data(contentsOf: url)) {
                return value
            }
        }
        return nil
    }

    private static func decodePath<T: Decodable>(_ path: String, _ type: T.Type) -> T? {
        let parts = path.split(separator: "/")
        guard parts.count == 2 else { return nil }
        let fileName = String(parts[1].dropLast(5))
        let candidates: [URL?] = [
            Bundle.main.url(forResource: fileName, withExtension: "json",
                            subdirectory: "UnitCatalog/\(parts[0])"),
            Bundle.main.url(forResource: fileName, withExtension: "json"),
        ]
        for url in candidates.compactMap({ $0 }) {
            if let value = try? JSONDecoder().decode(T.self, from: Data(contentsOf: url)) {
                return value
            }
        }
        return nil
    }
}
