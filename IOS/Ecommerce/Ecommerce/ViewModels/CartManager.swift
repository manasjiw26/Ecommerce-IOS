import Foundation
import Combine
import SwiftUI

struct CartItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var backendId: Int?
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
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadCart()
        
        AuthSession.shared.$currentUser
            .dropFirst()
            .sink { [weak self] user in
                Task {
                    await self?.handleUserChange(user: user)
                }
            }
            .store(in: &cancellables)
            
        // Initial fetch if logged in
        if let user = AuthSession.shared.currentUser {
            Task { await fetchBackendCart(userId: user.id) }
        }
    }
    
    var total: Double {
        items.reduce(0) { $0 + ($1.product.price * Double($1.quantity)) }
    }
    
    private func handleUserChange(user: AuthUser?) async {
        if let user = user {
            // Merge guest cart to backend, or just fetch if empty
            if !items.isEmpty {
                for item in items {
                    _ = try? await APIService.shared.addToCart(userId: user.id, productId: item.product.id, quantity: item.quantity)
                }
            }
            await fetchBackendCart(userId: user.id)
        } else {
            // Logged out
            items.removeAll()
            saveCart()
        }
    }
    
    private func fetchBackendCart(userId: String) async {
        do {
            let backendItems = try await APIService.shared.fetchCart(userId: userId)
            self.items = backendItems.map { bItem in
                CartItem(id: UUID(), backendId: bItem.id, product: bItem.products, quantity: bItem.quantity)
            }
            saveCart()
        } catch {
            print("Failed to fetch backend cart: \(error)")
        }
    }
    
    func addToCart(product: Product) {
        addToCart(product: product, quantity: 1)
    }

    func addToCart(product: Product, quantity: Int) {
        guard quantity != 0 else { return }
        if let index = items.firstIndex(where: { $0.product.id == product.id }) {
            items[index].quantity += quantity
            if items[index].quantity < 1 { items[index].quantity = 1 }
            if let user = AuthSession.shared.currentUser {
                Task {
                    _ = try? await APIService.shared.addToCart(userId: user.id, productId: product.id, quantity: quantity)
                    await fetchBackendCart(userId: user.id)
                }
            }
        } else {
            let newItem = CartItem(product: product, quantity: max(1, quantity))
            items.append(newItem)
            if let user = AuthSession.shared.currentUser {
                Task {
                    _ = try? await APIService.shared.addToCart(userId: user.id, productId: product.id, quantity: quantity)
                    await fetchBackendCart(userId: user.id)
                }
            }
        }
        RecommendationEngine.shared.logEvent(productId: product.id, eventType: "cart_add")
        saveCart()
    }
    
    func removeFromCart(product: Product) {
        if let index = items.firstIndex(where: { $0.product.id == product.id }) {
            let item = items[index]
            if items[index].quantity > 1 {
                items[index].quantity -= 1
                if let user = AuthSession.shared.currentUser {
                    Task {
                        // The backend `POST /cart` endpoint updates or inserts. 
                        // Wait, it ADDS quantity. We need a way to set or decrement.
                        // Wait! The backend route `POST /cart` does: `quantity: existingItem.quantity + quantity`.
                        // If we pass `-1`, it decrements!
                        _ = try? await APIService.shared.addToCart(userId: user.id, productId: product.id, quantity: -1)
                        await fetchBackendCart(userId: user.id)
                    }
                }
            } else {
                let backendIdToRemove = item.backendId
                items.remove(at: index)
                if AuthSession.shared.currentUser != nil, let backendId = backendIdToRemove {
                    Task {
                        try? await APIService.shared.removeFromCart(itemId: backendId)
                    }
                }
            }
            RecommendationEngine.shared.logEvent(productId: product.id, eventType: "cart_remove")
            saveCart()
        }
    }

    // Remove the entire line item, regardless of quantity.
    func removeLineItem(product: Product) {
        guard let index = items.firstIndex(where: { $0.product.id == product.id }) else { return }
        let item = items[index]
        items.remove(at: index)
        if AuthSession.shared.currentUser != nil, let backendId = item.backendId {
            Task { try? await APIService.shared.removeFromCart(itemId: backendId) }
        }
        RecommendationEngine.shared.logEvent(productId: product.id, eventType: "cart_remove")
        saveCart()
    }
    
    func removeAll() {
        items.removeAll()
        saveCart()
        // Optionally clear backend cart if needed, but OrderManager usually handles clearing on success.
    }
    
    private func saveCart() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadCart() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([CartItem].self, from: data) {
            
            items = decoded
        }
    }
}
