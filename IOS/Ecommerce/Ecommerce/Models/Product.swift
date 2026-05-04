import Foundation

struct Product: Codable, Identifiable {
    let id: Int
    let name: String
    let price: Double
    let description: String?
    let imageUrl: String?
    let category: String?
    let stock: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, price, description, category, stock
        case imageUrl = "image_url"
    }
}
