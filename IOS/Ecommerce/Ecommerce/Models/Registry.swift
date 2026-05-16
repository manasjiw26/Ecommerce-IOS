import Foundation

struct Registry: Codable, Identifiable {
    let id: String
    let userId: String
    let eventType: String
    let eventDate: String
    let eventLocation: String?
    let isPublic: Bool
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case eventType = "event_type"
        case eventDate = "event_date"
        case eventLocation = "event_location"
        case isPublic = "is_public"
        case createdAt = "created_at"
    }
}

struct RegistryItem: Codable, Identifiable {
    let id: String
    let registryId: String
    let productId: Int
    let quantityRequested: Int
    let quantityReceived: Int
    let isMostWanted: Bool
    let products: Product?
    
    enum CodingKeys: String, CodingKey {
        case id
        case registryId = "registry_id"
        case productId = "product_id"
        case quantityRequested = "quantity_requested"
        case quantityReceived = "quantity_received"
        case isMostWanted = "is_most_wanted"
        case products
    }
}

struct RegistryCreationDTO: Codable {
    let userId: String
    let eventType: String
    let eventDate: String
    let eventLocation: String?
    let isPublic: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case eventType = "event_type"
        case eventDate = "event_date"
        case eventLocation = "event_location"
        case isPublic = "is_public"
    }
}
