import Foundation

/// Custom URL scheme for widget and external deep links.
enum AppDeepLink {
    enum Destination: Equatable, Sendable {
        /// Collection filtered to the first pipeline stage (on the sprue / backlog).
        case collectionBacklog
        case musterHome
        case musterRoster(UUID)
    }

    static let scheme = "minimuster"

    static var collectionBacklogURL: URL {
        URL(string: "\(scheme)://collection/backlog")!
    }

    static func musterURL(rosterId: UUID) -> URL {
        URL(string: "\(scheme)://muster/\(rosterId.uuidString.lowercased())")!
    }

    static func destination(from url: URL) -> Destination? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        let host = url.host?.lowercased() ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = path.split(separator: "/").map(String.init)

        if host == "muster" || (host.isEmpty && parts.first == "muster") {
            let rosterParts = host == "muster" ? parts : Array(parts.dropFirst())
            if rosterParts.isEmpty {
                return .musterHome
            }
            if let id = UUID(uuidString: rosterParts.last ?? "") {
                return .musterRoster(id)
            }
            return .musterHome
        }

        let backlogPath = path.lowercased()
        if host == "collection", backlogPath == "backlog" { return .collectionBacklog }
        if host.isEmpty, backlogPath == "collection/backlog" { return .collectionBacklog }
        return nil
    }
}
