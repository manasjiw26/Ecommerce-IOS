import Foundation
import Combine
import SwiftUI

// MARK: - Intelligence Level
enum RecommendationLevel {
    case empty        // 0 items — show popular
    case single       // 1 item — simple complements
    case contextual   // 2–3 related items — setup context
    case intent       // 4+ items — lifestyle/intent
    case multiContext // mixed unrelated categories
}

@MainActor
class PairItWithViewModel: ObservableObject {
    @Published var recommendations: [PairItWithProduct] = []
    @Published var isLoading: Bool = false
    @Published var contextSubheading: String = "Handpicked for you"
    @Published var intelligenceLevel: RecommendationLevel = .empty

    private var fetchTask: Task<Void, Never>?
    private let service = RecommendationService.shared

    init() {}

    // MARK: - Public Trigger

    /// Triggers a debounced backend fetch and immediately updates the
    /// subheading to reflect the current cart state.
    func fetchRecommendations(cartItems: [CartItem]) {
        let cartProductIds = Set(cartItems.map { $0.product.id })

        // Optimistically remove items that are now in the cart so it feels instant
        withAnimation(.easeInOut(duration: 0.35)) {
            self.recommendations.removeAll { cartProductIds.contains($0.product.id) }
            updateLevel(cartItems: cartItems)
        }

        fetchTask?.cancel()
        fetchTask = Task {
            // 800ms debounce — absorbs rapid add/remove/quantity taps
            do {
                try await Task.sleep(nanoseconds: 800_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            // Show shimmer to indicate refresh
            isLoading = true

            // Send cart items to backend — cart is now the PRIMARY signal
            let (aiContext, results) = await service.fetchRecommendations(cartItems: cartItems)

            guard !Task.isCancelled else { return }

            // Filter out items that are already in the cart (defense in depth)
            let filteredResults = results.filter { !cartProductIds.contains($0.product.id) }

            withAnimation(.easeInOut(duration: 0.4)) {
                self.recommendations = filteredResults

                // Use backend-generated ai_context as the subheading if available.
                // Falls back to local heuristics only when backend doesn't provide one.
                if !aiContext.isEmpty {
                    self.contextSubheading = aiContext
                } else {
                    updateLevel(cartItems: cartItems)
                }
            }
            isLoading = false
        }
    }

    // MARK: - Fallback Level & Subheading Logic
    // Used only when backend doesn't provide ai_context (network error, etc.)

    private func updateLevel(cartItems: [CartItem]) {
        let count = cartItems.count

        if count == 0 {
            intelligenceLevel = .empty
            contextSubheading = "Handpicked for you"
            return
        }

        // Detect unique categories in the cart
        let cartCategories = Set(cartItems.compactMap { $0.product.category?.lowercased() })

        // Multi-context: 3+ distinct categories = mixed intent
        if cartCategories.count >= 3 && count >= 3 {
            intelligenceLevel = .multiContext
            contextSubheading = "Suggestions across your shopping interests"
            return
        }

        switch count {
        case 1:
            intelligenceLevel = .single
            contextSubheading = singleItemSubheading(cartItems: cartItems)

        case 2...3:
            intelligenceLevel = .contextual
            contextSubheading = contextualSubheading(cartCategories: cartCategories)

        default: // 4+
            intelligenceLevel = .intent
            contextSubheading = intentSubheading(cartCategories: cartCategories)
        }
    }

    // MARK: Fallback Subheading Generators

    private func singleItemSubheading(cartItems: [CartItem]) -> String {
        let category = cartItems.first?.product.category?.lowercased() ?? ""
        // Check tags array instead of itemTag
        let hasCulinary = cartItems.first?.product.tags?.contains { $0.lowercased().contains("cook") || $0.lowercased().contains("culinary") } ?? false
        let hasCoffee = cartItems.first?.product.tags?.contains { $0.lowercased().contains("coffee") } ?? false

        if category.contains("cook") || hasCulinary {
            return "Popular pairings for your cookware"
        } else if category.contains("coffee") || hasCoffee {
            return "Essential additions for your coffee setup"
        } else if category.contains("bake") {
            return "Perfect pairings for your baking essentials"
        } else if category.contains("outdoor") {
            return "Complement your outdoor selection"
        }
        return "Popular pairings for your selection"
    }

    private func contextualSubheading(cartCategories: Set<String>) -> String {
        if cartCategories.contains(where: { $0.contains("bake") || $0.contains("pastry") }) {
            return "Looks like you're building a baking setup"
        } else if cartCategories.contains(where: { $0.contains("coffee") || $0.contains("espresso") }) {
            return "Perfect additions for your coffee corner"
        } else if cartCategories.contains(where: { $0.contains("cook") || $0.contains("culinary") }) {
            return "Complete your kitchen essentials"
        } else if cartCategories.contains(where: { $0.contains("outdoor") || $0.contains("dining") }) {
            return "Complete your dining essentials"
        } else if cartCategories.contains(where: { $0.contains("host") || $0.contains("serving") }) {
            return "Everything for a perfect hosting setup"
        }
        return "Looks like you're building something special"
    }

    private func intentSubheading(cartCategories: Set<String>) -> String {
        if cartCategories.contains(where: { $0.contains("host") || $0.contains("dining") || $0.contains("serving") }) {
            return "Curated for your hosting experience"
        } else if cartCategories.contains(where: { $0.contains("outdoor") }) {
            return "Complete your outdoor entertaining setup"
        } else if cartCategories.contains(where: { $0.contains("cook") || $0.contains("culinary") }) {
            return "Complete your modern kitchen setup"
        } else if cartCategories.contains(where: { $0.contains("coffee") }) {
            return "Curated for your luxury coffee corner"
        }
        return "Curated recommendations for your experience"
    }
}
