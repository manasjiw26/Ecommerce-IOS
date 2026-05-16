import Foundation
import Combine

@MainActor
class PairItWithViewModel: ObservableObject {
    @Published var recommendations: [PairItWithProduct] = []
    
    // Pairing rules: Map a tag/category found in cart to a list of categories to recommend
    private let pairingRules: [String: [String]] = [
        "culinary": ["utensils", "linens", "serving"],
        "cookware": ["utensils", "linens", "serving tools"],
        "coffee": ["accessories", "food", "mugs"],
        "hosting": ["decor", "serving", "linens"],
        "home_sanctuary": ["decor", "scents", "pillows"]
    ]
    
    init() {}
    
    func generateRecommendations(from cartItems: [CartItem], allProducts: [Product]) {
        guard !allProducts.isEmpty else { return }
        
        if cartItems.isEmpty {
            // Show a curated selection from real products
            self.recommendations = allProducts
                .filter { $0.stock ?? 0 > 0 }
                .prefix(5)
                .map { PairItWithProduct(product: $0, recommendationLabel: "Top Pick") }
            return
        }
        
        // 1. Identify what's in the cart
        var cartProductIds: Set<Int> = []
        var detectedTags: Set<String> = []
        var detectedCategories: Set<String> = []
        
        for item in cartItems {
            cartProductIds.insert(item.product.id)
            if let tags = item.product.tags {
                for tag in tags {
                    detectedTags.insert(tag)
                }
            }
            if let category = item.product.category {
                detectedCategories.insert(category)
            }
        }
        
        // 2. Determine target categories based on pairing rules
        var targetCategories: Set<String> = []
        for tag in detectedTags {
            if let targets = pairingRules[tag] {
                targetCategories.formUnion(targets)
            }
        }
        for category in detectedCategories {
            if let targets = pairingRules[category.lowercased()] {
                targetCategories.formUnion(targets)
            }
        }
        
        // 3. Score real products from the catalog
        var scoredProducts: [(product: Product, score: Int, label: String)] = []
        
        for product in allProducts {
            // Exclude items already in cart
            guard !cartProductIds.contains(product.id) else { continue }
            
            var score = 0
            var label = "Recommended"
            
            // Check if product belongs to a target category
            if let category = product.category?.lowercased(), targetCategories.contains(category) {
                score += 10
            }
            
            // Check for tag overlap
            if let tags = product.tags {
                for tag in tags {
                    if detectedTags.contains(tag) {
                        score += 5
                        if label == "Recommended" {
                            label = "Similar Style"
                        }
                        break
                    }
                }
            }
            
            if score > 0 {
                scoredProducts.append((product, score, label))
            }
        }
        
        // 4. Sort and limit
        let topResults = scoredProducts
            .sorted { $0.score > $1.score }
            .prefix(6)
            .map { PairItWithProduct(product: $0.product, recommendationLabel: $0.label) }
        
        // 5. Fallback if not enough matches
        if topResults.count < 3 {
            var combined = Array(topResults)
            let existingIds = Set(combined.map { $0.product.id })
            
            let fillers = allProducts
                .filter { !cartProductIds.contains($0.id) && !existingIds.contains($0.id) }
                .prefix(3 - topResults.count)
                .map { PairItWithProduct(product: $0, recommendationLabel: "You Might Like") }
            
            combined.append(contentsOf: fillers)
            self.recommendations = combined
        } else {
            self.recommendations = Array(topResults)
        }
    }
}
