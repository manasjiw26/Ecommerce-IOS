import Foundation

struct ProductReview: Codable, Identifiable {
    let id: String
    let productId: Int
    let userId: String
    let rating: Int
    let body: String
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case userId = "user_id"
        case rating
        case body
        case createdAt = "created_at"
    }
}
