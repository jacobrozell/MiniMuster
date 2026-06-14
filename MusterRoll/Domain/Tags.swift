import Foundation

/// `#tag` extraction from notes. Ports `js/core/tags.js` (regex `#[\w-]+`), returning the
/// lowercased tags without the leading `#`.
enum Tags {
    static func extract(_ notes: String) -> [String] {
        notes.matches(of: /#[\w-]+/).map {
            String($0.output.dropFirst()).lowercased()
        }
    }
}
