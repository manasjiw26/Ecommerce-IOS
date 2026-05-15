import Foundation

struct Product: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let price: Double
    let description: String?
    let imageUrl: String?
    let category: String?
    let stock: Int?
    let aiReasoning: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, price, description, category, stock
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
