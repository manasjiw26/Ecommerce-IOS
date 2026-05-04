import Foundation
import Combine

@MainActor
class ProductViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    func fetchProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            products = try await APIService.shared.fetchProducts()
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
