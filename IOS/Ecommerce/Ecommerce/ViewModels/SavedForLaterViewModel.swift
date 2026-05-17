import Foundation
import Combine

@MainActor
final class SavedForLaterViewModel: ObservableObject {
    @Published var items: [SavedForLaterItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var deviceId: String { RecommendationEngine.shared.deviceId }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await SavedForLaterService.shared.list(deviceId: deviceId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(productId: Int) async {
        do {
            try await SavedForLaterService.shared.remove(deviceId: deviceId, productId: productId)
            items.removeAll { $0.product?.id == productId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isSaved(productId: Int) -> Bool {
        return items.contains { $0.product?.id == productId }
    }

    func toggleSave(product: Product) async {
        let currentlySaved = isSaved(productId: product.id)
        
        // Optimistic update
        if currentlySaved {
            items.removeAll { $0.product?.id == product.id }
        } else {
            let mockItem = SavedForLaterItem(
                id: UUID().uuidString,
                savedAt: ISO8601DateFormatter().string(from: Date()),
                product: product
            )
            items.append(mockItem)
        }
        
        // Backend sync
        do {
            if currentlySaved {
                try await SavedForLaterService.shared.remove(deviceId: deviceId, productId: product.id)
            } else {
                try await SavedForLaterService.shared.save(deviceId: deviceId, productId: product.id)
            }
        } catch {
            // Revert on failure
            await refresh()
            errorMessage = error.localizedDescription
        }
    }
}

