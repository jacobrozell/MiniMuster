import Foundation

/// User-facing app identity (display name only; bundle ID unchanged).
enum AppInfo {
    static let displayName = "MiniMuster"

    static var isUITesting: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("UI-Testing")
            || args.contains("UI-Testing-Persistent")
            || args.contains("UI-Testing-Seeded")
    }
}
