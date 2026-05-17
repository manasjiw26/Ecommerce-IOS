import Foundation
import Combine
import SwiftUI

struct CartItem: Identifiable, Codable, Equatable {
    var backendId: Int?
    let product: Product
    var quantity: Int

    // Stable identity for SwiftUI lists and persistence merging.
    // This also prevents transient UI "duplication" during async refreshes.
    var id: Int { product.id }

    static func == (lhs: CartItem, rhs: CartItem) -> Bool {
        lhs.product.id == rhs.product.id && lhs.quantity == rhs.quantity
    }
}

@MainActor
class CartManager: ObservableObject {
    @Published private(set) var items: [CartItem] = []
    private let saveKey = "SavedCart"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Promo code
    /// Applied promo code string (nil if none applied).
    @Published private(set) var appliedPromoCode: String? = nil
    /// Discount percentage (0–100).
    @Published private(set) var promoDiscountPercent: Double = 0.0

    /// Flat discount amount derived from current subtotal × discount %.
    var promoDiscountAmount: Double {
        guard promoDiscountPercent > 0 else { return 0 }
        let subtotal = items.reduce(0) { $0 + ($1.product.price * Double($1.quantity)) }
        return subtotal * promoDiscountPercent / 100.0
    }

    /// Validates and applies a promo code. Returns an error message if invalid, nil on success.
    @discardableResult
    func applyPromo(code: String) async -> String? {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        do {
            let res = try await APIService.shared.applyPromo(code: normalized)
            let discountPercent = res.promo.discount_pct ?? 0.0
            
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    self.appliedPromoCode = normalized
                    self.promoDiscountPercent = Double(discountPercent)
                }
            }
            return nil
        } catch {
            await MainActor.run {
                withAnimation {
                    self.appliedPromoCode = nil
                    self.promoDiscountPercent = 0.0
                }
            }
            return error.localizedDescription
        }
    }

    func removePromo() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            appliedPromoCode = nil
            promoDiscountPercent = 0.0
        }
    }

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
            // Backend can occasionally return duplicate rows for the same product_id.
            // Merge them so the UI always shows a single line item per product.
            var byProduct: [Int: (backendId: Int?, product: Product, quantity: Int)] = [:]
            for bItem in backendItems {
                let pid = bItem.products.id
                if var existing = byProduct[pid] {
                    existing.quantity += bItem.quantity
                    // keep the first backend id as the delete handle
                    byProduct[pid] = existing
                } else {
                    byProduct[pid] = (backendId: bItem.id, product: bItem.products, quantity: bItem.quantity)
                }
            }
            self.items = byProduct.values.map { merged in
                CartItem(backendId: merged.backendId, product: merged.product, quantity: merged.quantity)
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

        // 1. Optimistic local update — always persisted immediately
        if let index = items.firstIndex(where: { $0.product.id == product.id }) {
            items[index].quantity += quantity
            if items[index].quantity < 1 { items[index].quantity = 1 }
        } else {
            items.append(CartItem(product: product, quantity: max(1, quantity)))
        }
        RecommendationEngine.shared.logEvent(productId: product.id, eventType: "cart_add")
        saveCart()

        // 2. Backend sync — only refreshes local state if the API call SUCCEEDS.
        // Never calls fetchBackendCart on failure to avoid wiping optimistic state.
        guard let user = AuthSession.shared.currentUser else { return }
        Task {
            do {
                try await APIService.shared.addToCart(userId: user.id, productId: product.id, quantity: quantity)
                await fetchBackendCart(userId: user.id)
            } catch {
                print("[CartManager] Backend addToCart failed, keeping local state: \(error.localizedDescription)")
            }
        }
    }

    func removeFromCart(product: Product) {
        guard let index = items.firstIndex(where: { $0.product.id == product.id }) else { return }
        let item = items[index]

        // 1. Optimistic local update
        if items[index].quantity > 1 {
            items[index].quantity -= 1
        } else {
            items.remove(at: index)
        }
        RecommendationEngine.shared.logEvent(productId: product.id, eventType: "cart_remove")
        saveCart()

        // 2. Backend sync — only refresh on success
        guard let user = AuthSession.shared.currentUser else { return }
        Task {
            do {
                // Backend POST /cart adds quantity; passing -1 decrements
                try await APIService.shared.addToCart(userId: user.id, productId: product.id, quantity: -1)
                await fetchBackendCart(userId: user.id)
            } catch {
                // Fallback: try delete if item backendId is known
                if let backendId = item.backendId {
                    try? await APIService.shared.removeFromCart(itemId: backendId)
                }
                print("[CartManager] Backend removeFromCart failed, keeping local state: \(error.localizedDescription)")
            }
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
        removePromo()
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
            // Merge any duplicates (same product) from local persistence.
            var byProduct: [Int: CartItem] = [:]
            for item in decoded {
                if var existing = byProduct[item.product.id] {
                    existing.quantity += item.quantity
                    byProduct[item.product.id] = existing
                } else {
                    byProduct[item.product.id] = item
                }
            }
            items = Array(byProduct.values)
        }
    }
}
