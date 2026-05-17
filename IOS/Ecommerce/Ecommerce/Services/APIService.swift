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
    
    /// Adds or increments a cart item. Returns the raw cart row (no joined product data).
    @discardableResult
    func addToCart(userId: String, productId: Int, quantity: Int) async throws -> [[String: Any]] {
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
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "Cart", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "Cart update failed"])
        }
        // Response is a plain cart_items row (no nested products). Just return it raw.
        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
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
    
    // MARK: - Promotions
    
    struct PromoResponse: Codable {
        struct PromoDetails: Codable {
            let code: String
            let discount_pct: Double?
            let discount_fixed: Double?
        }
        let promo: PromoDetails
    }
    
    func applyPromo(code: String) async throws -> PromoResponse {
        guard let url = URL(string: "\(APIService.baseURL)/chat/promotions/apply") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "code": code
        ])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "Promo", code: (response as? HTTPURLResponse)?.statusCode ?? 400,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "Invalid or expired promo code."])
        }
        return try JSONDecoder().decode(PromoResponse.self, from: data)
    }
}
