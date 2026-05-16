import Foundation
import Combine
import SwiftUI

struct CartItem: Identifiable, Codable, Equatable {
    var id = UUID()
    let product: Product
    var quantity: Int

    static func == (lhs: CartItem, rhs: CartItem) -> Bool {
        lhs.product.id == rhs.product.id && lhs.quantity == rhs.quantity
    }
}

@MainActor
class CartManager: ObservableObject {
    @Published private(set) var items: [CartItem] = []
    private let saveKey = "SavedCart"
    
    init() {
        loadCart()
    }
    
    var total: Double {
        items.reduce(0) { $0 + ($1.product.price * Double($1.quantity)) }
    }
    
    func addToCart(product: Product) {
        if let index = items.firstIndex(where: { $0.product.id == product.id }) {
            items[index].quantity += 1
        } else {
            items.append(CartItem(product: product, quantity: 1))
        }
        RecommendationEngine.shared.logEvent(productId: product.id, eventType: "cart_add")
        saveCart()
    }
    
    func removeFromCart(product: Product) {
        if let index = items.firstIndex(where: { $0.product.id == product.id }) {
            if items[index].quantity > 1 {
                items[index].quantity -= 1
            } else {
                items.remove(at: index)
            }
            RecommendationEngine.shared.logEvent(productId: product.id, eventType: "cart_remove")
            saveCart()
        }
    }
    
    func removeAll() {
        items.removeAll()
        saveCart()
    }
    
    private func saveCart() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadCart() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([CartItem].self, from: data) {
            
            // Re-inject mock tags to support legacy carts saved before itemTag was added
            let products = decoded.map { $0.product }
            let taggedProducts = MockDataService.shared.injectMockTags(to: products)
            
            items = zip(decoded, taggedProducts).map { item, taggedProduct in
                CartItem(id: item.id, product: taggedProduct, quantity: item.quantity)
            }
        }
    }
}
