import Foundation
import Combine

@MainActor
final class BagViewModel: ObservableObject {
    @Published var stockMap: [Int: Int] = [:]
    @Published var isCheckingStock: Bool = false

    @Published var selectedProductIds: Set<Int> = []
    @Published var savedCount: Int = 0

    @Published var coach: CartCoachResponse? = nil
    @Published var resurface: ResurfaceResponse? = nil
    @Published var coachError: String? = nil
    @Published var isLoadingIntelligence: Bool = false

    @Published var addOnEngraving: Set<Int> = []
    @Published var addOnProtection: Set<Int> = []

    private var previousProductIds: Set<Int> = []

    private var deviceId: String { RecommendationEngine.shared.deviceId }

    func syncSelection(with items: [CartItem]) {
        let current = Set(items.map { $0.product.id })
        if selectedProductIds.isEmpty {
            selectedProductIds = current
        } else {
            let newIds = current.subtracting(previousProductIds)
            selectedProductIds = selectedProductIds.intersection(current).union(newIds)
        }
        previousProductIds = current
    }

    func selectedItems(from items: [CartItem]) -> [CartItem] {
        items.filter { selectedProductIds.contains($0.product.id) }
    }

    func subtotal(for selectedItems: [CartItem]) -> Double {
        let base = selectedItems.reduce(0) { $0 + ($1.product.price * Double($1.quantity)) }
        let engraving = selectedItems.reduce(0) { sum, it in
            sum + (addOnEngraving.contains(it.product.id) ? 15.0 * Double(it.quantity) : 0)
        }
        let protection = selectedItems.reduce(0) { sum, it in
            sum + (addOnProtection.contains(it.product.id) ? 49.0 : 0)
        }
        return base + engraving + protection
    }

    func refreshStock(items: [CartItem]) async {
        guard !items.isEmpty else {
            stockMap = [:]
            return
        }
        isCheckingStock = true
        defer { isCheckingStock = false }

        let baseURL = APIService.baseURL
        for item in items {
            guard let url = URL(string: "\(baseURL)/products/\(item.product.id)/stock") else { continue }
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let json = try? JSONDecoder().decode([String: Int].self, from: data),
               let stock = json["stock"] {
                stockMap[item.product.id] = stock
            }
        }
    }

    func autoDeselectOverStock(items: [CartItem]) {
        for item in items {
            let available = stockMap[item.product.id] ?? (item.product.stock ?? 999)
            if available < item.quantity {
                selectedProductIds.remove(item.product.id)
            }
        }
    }

    func refreshIntelligence(selectedItems: [CartItem]) async {
        isLoadingIntelligence = true
        coachError = nil
        defer { isLoadingIntelligence = false }

        do {
            coach = try await CartIntelligenceService.shared.cartCoach(cartItems: selectedItems)
        } catch {
            coach = nil
            coachError = error.localizedDescription
        }

        do {
            resurface = try await CartIntelligenceService.shared.resurface(deviceId: deviceId)
        } catch {
            resurface = nil
        }

        // Saved count comes from resurface response (all_saved).
        if let resurface {
            savedCount = resurface.allSaved.count
        }
    }
}

