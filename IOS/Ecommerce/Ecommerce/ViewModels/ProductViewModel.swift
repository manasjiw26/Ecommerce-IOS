import Foundation
import Combine

@MainActor
class ProductViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    func fetchProducts() async {
        // Only show full-page skeleton if we have no products yet
        if products.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        
        var retryCount = 0
        let maxRetries = 2
        
        while retryCount <= maxRetries {
            do {
                let fetchedProducts = try await APIService.shared.fetchProducts()
                self.products = MockDataService.shared.injectMockTags(to: fetchedProducts)
                self.errorMessage = nil
                break
            } catch {
                // Silence "cancelled" errors (they are normal during refreshes)
                if (error as? URLError)?.code == .cancelled {
                    break
                }

                if retryCount < maxRetries {
                    retryCount += 1
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                }
                
                // Only show error if we have no data at all
                if self.products.isEmpty {
                    self.errorMessage = "Failed to load: \(error.localizedDescription)"
                }
                print("⚠️ Refresh error: \(error.localizedDescription)")
                break // Don't loop forever if it's a permanent error
            }
        }
        
        self.isLoading = false
    }
}
