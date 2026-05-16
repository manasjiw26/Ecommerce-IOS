import Foundation

class MockDataService {
    static let shared = MockDataService()
    
    // Injects temporary tags into products for occasion detection
    func injectMockTags(to products: [Product]) -> [Product] {
        return products.map { product in
            var tag: String? = nil
            
            let name = product.name.lowercased()
            
            if name.contains("glass") || name.contains("wine") || name.contains("appetizer") || name.contains("platter") || name.contains("hosting") {
                tag = "hosting"
            } else if name.contains("candle") || name.contains("decor") || name.contains("vase") || name.contains("scent") || name.contains("pillow") {
                tag = "home_sanctuary"
            } else if name.contains("pan") || name.contains("pot") || name.contains("chef") || name.contains("knife") || name.contains("oven") {
                tag = "culinary"
            }
            
            return Product(
                id: product.id,
                name: product.name,
                price: product.price,
                description: product.description,
                imageUrl: product.imageUrl,
                category: product.category,
                stock: product.stock,
                aiReasoning: product.aiReasoning,
                itemTag: tag
            )
        }
    }
}
