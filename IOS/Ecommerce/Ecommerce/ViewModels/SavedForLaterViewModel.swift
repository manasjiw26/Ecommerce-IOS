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
}

