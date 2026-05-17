import Foundation
import Combine

class RecommendationEngine: ObservableObject {
    static let shared = RecommendationEngine()
    
    @Published var recommendedProducts: [Product] = []
    @Published var searchResults: [Product] = []
    
    // MARK: - Recently Viewed (local cache, max 10 products)
    @Published var recentlyViewedProducts: [Product] = []
    private let recentlyViewedKey = "RecentlyViewedProducts"
    private let maxRecentlyViewed = 10
    
    private let deviceIdKey = "UserDeviceId"
    
    // Uses the shared config URL (change in Config.swift to test locally)
    private let baseURL = "\(Config.apiBaseURL)/ai"
    
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
        loadRecentlyViewed()
        // Kick off initial fetch in background
        Task { await fetchRecommendations() }
    }
    
    // MARK: - Recently Viewed Persistence
    
    private func loadRecentlyViewed() {
        guard let data = UserDefaults.standard.data(forKey: recentlyViewedKey),
              let products = try? JSONDecoder().decode([Product].self, from: data) else { return }
        recentlyViewedProducts = products
    }
    
    private func saveRecentlyViewed() {
        guard let data = try? JSONEncoder().encode(recentlyViewedProducts) else { return }
        UserDefaults.standard.set(data, forKey: recentlyViewedKey)
    }
    
    func recordView(product: Product) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Remove duplicate, insert at front (most recent first)
            self.recentlyViewedProducts.removeAll { $0.id == product.id }
            self.recentlyViewedProducts.insert(product, at: 0)
            // Keep max 10
            if self.recentlyViewedProducts.count > self.maxRecentlyViewed {
                self.recentlyViewedProducts = Array(self.recentlyViewedProducts.prefix(self.maxRecentlyViewed))
            }
            self.saveRecentlyViewed()
        }
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
                // Refresh recommendations silently after each event
                Task { await self.fetchRecommendations() }
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
                    let products = try JSONDecoder().decode([Product].self, from: data)
                    DispatchQueue.main.async { self.searchResults = products }
                } catch {
                    print("Failed to decode search results: \(error)")
                }
            }
        }.resume()
    }
    
    func fetchSimilarProducts(to product: Product) async -> [Product] {
        guard let url = URL(string: "\(baseURL)/search") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let query: String
        if let tags = product.tags, !tags.isEmpty {
            query = tags.joined(separator: " ")
        } else {
            query = product.category ?? product.name
        }
        let body: [String: Any] = ["query": query]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let products = try JSONDecoder().decode([Product].self, from: data)
            return products.filter { $0.id != product.id }
        } catch {
            print("❌ Failed to fetch similar products: \(error)")
            return []
        }
    }
}
