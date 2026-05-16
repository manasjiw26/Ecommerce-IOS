import Foundation

struct Occasion: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let description: String
    let tag: String // The tag used to filter products
    let backgroundImageUrl: String? // Can be asset name or remote URL
    let isLocalAsset: Bool
    
    static func == (lhs: Occasion, rhs: Occasion) -> Bool {
        lhs.title == rhs.title && lhs.subtitle == rhs.subtitle && lhs.tag == rhs.tag
    }
}
