import Foundation

struct Registry: Codable, Identifiable {
    let id: String
    let userId: String
    let eventType: String
    let eventDate: String
    let eventLocation: String?
    let isPublic: Bool
    let createdAt: String?
    let shareToken: String?
    let theme: String?
    let budget: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case eventType = "event_type"
        case eventDate = "event_date"
        case eventLocation = "event_location"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case shareToken = "share_token"
        case theme
        case budget
    }
}

struct RegistryItem: Codable, Identifiable {
    let id: String
    let registryId: String
    let productId: Int
    let quantityRequested: Int
    var quantityReceived: Int
    var isMostWanted: Bool
    var isGroupGift: Bool?
    let products: Product?
    let aiReason: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case registryId = "registry_id"
        case productId = "product_id"
        case quantityRequested = "quantity_requested"
        case quantityReceived = "quantity_received"
        case isMostWanted = "is_most_wanted"
        case isGroupGift = "is_group_gift"
        case products = "products"
        case product = "product"
        case aiReason = "ai_reason"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        registryId = try container.decode(String.self, forKey: .registryId)
        productId = try container.decode(Int.self, forKey: .productId)
        quantityRequested = try container.decode(Int.self, forKey: .quantityRequested)
        quantityReceived = try container.decode(Int.self, forKey: .quantityReceived)
        isMostWanted = try container.decode(Bool.self, forKey: .isMostWanted)
        isGroupGift = try container.decodeIfPresent(Bool.self, forKey: .isGroupGift)
        aiReason = try container.decodeIfPresent(String.self, forKey: .aiReason)
        
        // Dynamically resolve Singular ("product") or Plural ("products") key from JSON response
        if container.contains(.products) {
            products = try container.decodeIfPresent(Product.self, forKey: .products)
        } else if container.contains(.product) {
            products = try container.decodeIfPresent(Product.self, forKey: .product)
        } else {
            products = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(registryId, forKey: .registryId)
        try container.encode(productId, forKey: .productId)
        try container.encode(quantityRequested, forKey: .quantityRequested)
        try container.encode(quantityReceived, forKey: .quantityReceived)
        try container.encode(isMostWanted, forKey: .isMostWanted)
        try container.encodeIfPresent(isGroupGift, forKey: .isGroupGift)
        try container.encodeIfPresent(products, forKey: .products)
        try container.encodeIfPresent(aiReason, forKey: .aiReason)
    }
}

struct RegistryCreationDTO: Codable {
    let userId: String
    let eventType: String
    let eventDate: String
    let eventLocation: String?
    let isPublic: Bool
    let theme: String?
    let budget: Double?
    
    init(userId: String, eventType: String, eventDate: String, eventLocation: String?, isPublic: Bool, theme: String? = nil, budget: Double? = nil) {
        self.userId = userId
        self.eventType = eventType
        self.eventDate = eventDate
        self.eventLocation = eventLocation
        self.isPublic = isPublic
        self.theme = theme
        self.budget = budget
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case eventType = "event_type"
        case eventDate = "event_date"
        case eventLocation = "event_location"
        case isPublic = "is_public"
        case theme
        case budget
    }
}
