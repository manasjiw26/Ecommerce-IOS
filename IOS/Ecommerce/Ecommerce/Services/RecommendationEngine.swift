import Foundation
import Combine

class RecommendationEngine: ObservableObject {
    static let shared = RecommendationEngine()
    
    @Published var recommendedProducts: [Product] = []
    @Published var searchResults: [Product] = []
    @Published private(set) var lastRefreshDate: Date?
    @Published private(set) var personalizationRevision = 0
    
    private let deviceIdKey = "UserDeviceId"
    private let interactionScoresKey = "ProductInteractionScores"
    private let categoryScoresKey = "CategoryInteractionScores"
    private let recentProductIdsKey = "RecentProductInteractionIds"
    
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
        // Kick off initial fetch in background
        Task { await fetchRecommendations() }
    }
    
    func logEvent(productId: Int, eventType: String) {
        recordLocalInteraction(productId: productId, eventType: eventType)

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
            await MainActor.run {
                self.recommendedProducts = products
                self.mergeRecommendationSignals(from: products)
                self.lastRefreshDate = Date()
            }
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
    
    func fetchSimilarProducts(to product: Product) async -> [Product] {
        guard let url = URL(string: "\(baseURL)/suggested-products") else { return [] }
        
        let body: [String: Any] = [
            "product_id": product.id,
            "device_id": deviceId
        ]
        
        // 1. Fetch Gemini-orchestrated [Similar, Complementary, Suggested] feed
        if let products = await performSearchRequest(url: url, body: body), !products.isEmpty {
            return products
        }
        
        // 2. Client-side network fallback if backend endpoint fails
        guard let fallbackUrl = URL(string: "\(baseURL)/search") else { return [] }
        let fallbackBody: [String: Any] = [
            "query": product.category ?? product.name,
            "device_id": deviceId
        ]
        
        if let fallbackProducts = await performSearchRequest(url: fallbackUrl, body: fallbackBody) {
            let filtered = fallbackProducts.filter { $0.id != product.id }
            return Array(filtered.prefix(8))
        }
        
        return []
    }

    private func performSearchRequest(url: URL, body: [String: Any]) async -> [Product]? {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            do {
                return try JSONDecoder().decode([Product].self, from: data)
            } catch {
                print("❌ Failed to decode search response: \(error)")
                if let str = String(data: data, encoding: .utf8) {
                    print("Raw response: \(str)")
                }
                return nil
            }
        } catch {
            print("❌ Network error: \(error)")
            return nil
        }
    }

    func getRecentlyViewedProducts(from allProducts: [Product]) -> [Product] {
        let recentIds = loadRecentProductIds()
        return recentIds.compactMap { id in allProducts.first(where: { $0.id == id }) }
    }

    func getPromotedProducts(from allProducts: [Product]) -> [Product] {
        return allProducts.filter { product in 
            guard let tags = product.tags else { return false }
            let lowerTags = tags.map { $0.lowercased() }
            return lowerTags.contains("promoted") || lowerTags.contains("featured") || lowerTags.contains("event") || lowerTags.contains("new") || lowerTags.contains("promotion")
        }
    }

    func personalize(_ products: [Product]) -> [Product] {
        let recommendedRank = Dictionary(
            uniqueKeysWithValues: recommendedProducts.enumerated().map { ($0.element.id, $0.offset) }
        )
        let productScores = loadScores(forKey: interactionScoresKey)
        let categoryScores = loadScores(forKey: categoryScoresKey)
        let recentIds = loadRecentProductIds()

        return products.sorted { lhs, rhs in
            let lhsScore = score(
                product: lhs,
                recommendedRank: recommendedRank,
                productScores: productScores,
                categoryScores: categoryScores,
                recentIds: recentIds
            )
            let rhsScore = score(
                product: rhs,
                recommendedRank: recommendedRank,
                productScores: productScores,
                categoryScores: categoryScores,
                recentIds: recentIds
            )

            if lhsScore == rhsScore {
                return lhs.id < rhs.id
            }
            return lhsScore > rhsScore
        }
    }

    private func score(
        product: Product,
        recommendedRank: [Int: Int],
        productScores: [String: Double],
        categoryScores: [String: Double],
        recentIds: [Int]
    ) -> Double {
        // Cap individual product click scores so they don't dominate forever
        var total = min(productScores[String(product.id)] ?? 0, 40)

        if let category = product.category?.lowercased() {
            let catScore = categoryScores[category] ?? 0
            total += min(catScore, 50) * 0.5
        }

        if let rank = recommendedRank[product.id] {
            total += max(10, 60 - Double(rank * 6))
        }

        if let recentIndex = recentIds.firstIndex(of: product.id) {
            total += max(0, 15 - Double(recentIndex * 3))
        }

        // Add a random noise factor to introduce new items
        total += Double.random(in: 0...40)

        // Boost for promoted or event-related tags
        if let tags = product.tags {
            let lowerTags = tags.map { $0.lowercased() }
            if lowerTags.contains("promoted") || lowerTags.contains("featured") || lowerTags.contains("event") || lowerTags.contains("new") || lowerTags.contains("promotion") {
                total += 35
            }
        }

        // Heavily penalize out of stock
        if let stock = product.stock, stock <= 0 {
            total -= 1000
        }

        return total
    }

    private func recordLocalInteraction(productId: Int, eventType: String) {
        let weight: Double
        switch eventType {
        case "cart_add":
            weight = 18
        case "cart_remove":
            weight = -4
        case "view":
            weight = 6
        default:
            weight = 3
        }

        updateScore(key: String(productId), delta: weight, storageKey: interactionScoresKey)
        updateRecentProductIds(with: productId)
        DispatchQueue.main.async {
            self.personalizationRevision += 1
        }
    }

    private func mergeRecommendationSignals(from products: [Product]) {
        for product in products {
            updateScore(key: String(product.id), delta: 4, storageKey: interactionScoresKey)
            if let category = product.category?.lowercased() {
                updateScore(key: category, delta: 2, storageKey: categoryScoresKey)
            }
        }
        personalizationRevision += 1
    }

    private func updateScore(key: String, delta: Double, storageKey: String) {
        var scores = loadScores(forKey: storageKey)
        let current = scores[key] ?? 0
        scores[key] = max(-20, min(120, current + delta))

        if let encoded = try? JSONEncoder().encode(scores) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadScores(forKey key: String) -> [String: Double] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func updateRecentProductIds(with productId: Int) {
        var ids = loadRecentProductIds()
        ids.removeAll { $0 == productId }
        ids.insert(productId, at: 0)
        ids = Array(ids.prefix(20))
        UserDefaults.standard.set(ids, forKey: recentProductIdsKey)
    }

    private func loadRecentProductIds() -> [Int] {
        UserDefaults.standard.array(forKey: recentProductIdsKey) as? [Int] ?? []
    }
}
