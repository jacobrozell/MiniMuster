import Foundation

/// Typed navigation destinations for the Collection tab.
enum CollectionRoute: Hashable {
    case overview
    case army(UUID)
    case unit(UUID)
}
