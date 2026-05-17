import Foundation

/// Represents a physical item available for purchase or registry addition in the ShopEase catalog.
/// Maps directly to the `products` table in the Supabase PostgreSQL database.
struct Product: Codable, Identifiable, Equatable {
    /// The unique identifier of the product (Primary Key in DB).
    let id: Int
    /// The display name of the product.
    let name: String
    /// The current retail price in USD.
    let price: Double
    /// Optional rich text or plain text description of the product.
    let description: String?
    /// Remote URL pointing to the primary display image.
    let imageUrl: String?
    /// The categorical classification (e.g., "Cookware", "Cutlery").
    let category: String?
    /// Current inventory count available for purchase.
    let stock: Int?
    /// Array of keyword tags for search and AI recommendations.
    let tags: [String]?
    /// Contextual reasoning provided dynamically by the AI Engine when recommending this product.
    let aiReasoning: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, price, description, category, stock, tags
        case imageUrl = "image_url"
        case aiReasoning = "ai_reasoning"
    }

    static func == (lhs: Product, rhs: Product) -> Bool {
        return lhs.id == rhs.id && 
               lhs.name == rhs.name && 
               lhs.price == rhs.price && 
               lhs.imageUrl == rhs.imageUrl && 
               lhs.stock == rhs.stock
    }
}
