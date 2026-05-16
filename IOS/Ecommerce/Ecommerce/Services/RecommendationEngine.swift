import Foundation
import Combine

class RecommendationEngine: ObservableObject {
    static let shared = RecommendationEngine()
    
    @Published var recommendedProducts: [Product] = []
    @Published var searchResults: [Product] = []
    
    private let deviceIdKey = "UserDeviceId"
    
    // Defaulting to localhost, assuming backend is running locally.
    // If deployed, this should point to your Render/Railway backend URL.
    private let baseURL = "https://ecommerce-ios.onrender.com/ai"
    
    var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: deviceIdKey) {
            return id
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: deviceIdKey)
            return newId
        }
    }
    
    private init() {
        // Kick off initial fetch in background
        Task { await fetchRecommendations() }
    }
    
    func logEvent(productId: Int, eventType: String) {
        guard let url = URL(string: "\(baseURL)/events") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "device_id": deviceId,
            "product_id": productId,
            "event_type": eventType
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error logging event: \(error)")
            } else {
                // If event was successfully logged, we can refresh the recommendations silently in background
                Task {
                    await self.fetchRecommendations()
                }
            }
        }.resume()
    }
    
    func fetchRecommendations() async {
        guard let url = URL(string: "\(baseURL)/recommend") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["device_id": deviceId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }
        if let products = try? JSONDecoder().decode([Product].self, from: data) {
            DispatchQueue.main.async { self.recommendedProducts = products }
        }
    }
    
    func searchProducts(query: String) {
        guard let url = URL(string: "\(baseURL)/search") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["query": query]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                do {
                    let decoder = JSONDecoder()
                    let products = try decoder.decode([Product].self, from: data)
                    DispatchQueue.main.async {
                        self.searchResults = products
                    }
                } catch {
                    print("Failed to decode search results: \(error)")
                }
            }
        }.resume()
    }
}
