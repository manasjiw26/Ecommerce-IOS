import Foundation

class APIService {
    static let shared = APIService()
    static let baseURL = Config.apiBaseURL
    private let baseURL_instance = APIService.baseURL
    
    func fetchProducts() async throws -> [Product] {
        guard let url = URL(string: "\(APIService.baseURL)/products") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 60 // Wait up to 60s for Render to wake up
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Product].self, from: data)
    }
    
    // MARK: - Cart Endpoints
    
    struct BackendCartItem: Codable {
        let id: Int
        let quantity: Int
        let products: Product
    }
    
    func fetchCart(userId: String) async throws -> [BackendCartItem] {
        guard let url = URL(string: "\(APIService.baseURL)/cart/\(userId)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([BackendCartItem].self, from: data)
    }
    
    func addToCart(userId: String, productId: Int, quantity: Int) async throws -> [BackendCartItem] {
        guard let url = URL(string: "\(APIService.baseURL)/cart") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "user_id": userId,
            "product_id": productId,
            "quantity": quantity
        ])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        // The backend returns the inserted/updated row, we can just decode it.
        // It doesn't return the full `products` joined object, but we just need it to succeed.
        return try JSONDecoder().decode([BackendCartItem].self, from: data)
    }
    
    func removeFromCart(itemId: Int) async throws {
        guard let url = URL(string: "\(APIService.baseURL)/cart/\(itemId)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
}
