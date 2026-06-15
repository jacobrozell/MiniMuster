import Foundation

/// Custom URL scheme for widget and external deep links.
enum AppDeepLink {
    enum Destination: Equatable, Sendable {
        /// Collection filtered to the first pipeline stage (on the sprue / backlog).
        case collectionBacklog
    }

    static let scheme = "minimuster"

    static var collectionBacklogURL: URL {
        URL(string: "\(scheme)://collection/backlog")!
    }

    static func destination(from url: URL) -> Destination? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        let host = url.host?.lowercased() ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        if host == "collection", path == "backlog" { return .collectionBacklog }
        if host.isEmpty, path == "collection/backlog" { return .collectionBacklog }
        return nil
    }
}
