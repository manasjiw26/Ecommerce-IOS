import Foundation

/// Represents a user's curated wishlist or gift registry.
/// Maps to the `registries` table in Supabase.
struct Registry: Codable, Identifiable {
    /// Unique UUID of the registry.
    let id: String
    /// UUID of the user who owns this registry.
    let userId: String
    /// The classification of the event (e.g., Wedding, Housewarming).
    let eventType: String
    /// The date the event is taking place (ISO 8601 format).
    let eventDate: String
    /// The physical or virtual location of the event.
    let eventLocation: String?
    /// Whether this registry can be searched publicly by guests.
    let isPublic: Bool
    /// Timestamp of when the registry was created.
    let createdAt: String?
    /// A unique short alphanumeric token used for shareable URLs.
    let shareToken: String?
    /// Custom styling theme applied to the registry page.
    let theme: String?
    /// Target monetary budget (if applicable) for the entire registry.
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        eventType = try container.decodeIfPresent(String.self, forKey: .eventType) ?? "Event"
        eventDate = try container.decodeIfPresent(String.self, forKey: .eventDate) ?? ""
        eventLocation = try container.decodeIfPresent(String.self, forKey: .eventLocation)
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? true
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        shareToken = try container.decodeIfPresent(String.self, forKey: .shareToken)
        theme = try container.decodeIfPresent(String.self, forKey: .theme)
        budget = try container.decodeIfPresent(Double.self, forKey: .budget)
    }
}

/// A specific product added to a registry, tracking requested vs. fulfilled quantities.
/// Maps to the `registry_items` table in Supabase.
struct RegistryItem: Codable, Identifiable {
    /// Unique UUID of the registry item.
    let id: String
    /// UUID of the parent registry this item belongs to.
    let registryId: String
    /// ID of the product linked to this item.
    let productId: Int
    /// Number of units requested by the registry owner.
    let quantityRequested: Int
    /// Number of units already purchased by guests.
    var quantityReceived: Int
    /// Flag indicating if the owner marked this as a top priority item.
    var isMostWanted: Bool
    /// Flag indicating if guests can contribute partial funds toward this item.
    var isGroupGift: Bool?
    /// The nested Product details (joined via Supabase relations).
    let products: Product?
    /// The AI's contextual reasoning for suggesting this item be added.
    let aiReason: String?
    /// The total monetary amount contributed towards this item (for group gifts).
    let totalContributed: Double?
    /// Evaluated boolean indicating if total contributions match the item's total cost.
    let isFullyFunded: Bool?
    /// Array of individual guest contributions toward this group gift.
    let contributions: [RegistryContribution]?
    
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
        case totalContributed = "total_contributed"
        case isFullyFunded = "is_fully_funded"
        case contributions
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        registryId = try container.decodeIfPresent(String.self, forKey: .registryId) ?? ""
        productId = try container.decodeIfPresent(Int.self, forKey: .productId) ?? 0
        quantityRequested = try container.decodeIfPresent(Int.self, forKey: .quantityRequested) ?? 1
        quantityReceived = try container.decodeIfPresent(Int.self, forKey: .quantityReceived) ?? 0
        isMostWanted = try container.decodeIfPresent(Bool.self, forKey: .isMostWanted) ?? false
        isGroupGift = try container.decodeIfPresent(Bool.self, forKey: .isGroupGift)
        aiReason = try container.decodeIfPresent(String.self, forKey: .aiReason)
        totalContributed = try container.decodeIfPresent(Double.self, forKey: .totalContributed)
        isFullyFunded = try container.decodeIfPresent(Bool.self, forKey: .isFullyFunded)
        contributions = try container.decodeIfPresent([RegistryContribution].self, forKey: .contributions)
        
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
        try container.encodeIfPresent(totalContributed, forKey: .totalContributed)
        try container.encodeIfPresent(isFullyFunded, forKey: .isFullyFunded)
        try container.encodeIfPresent(contributions, forKey: .contributions)
    }
}

struct RegistryContribution: Codable, Identifiable {
    let id: String
    let registryItemId: String
    let contributorName: String
    let amount: Double
    let message: String?
    let createdAt: String?
    let isAnonymous: Bool?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id
        case registryItemId = "registry_item_id"
        case contributorName = "contributor_name"
        case amount
        case message
        case createdAt = "created_at"
        case isAnonymous = "is_anonymous"
        case email
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
