import Foundation

/// Single-responsibility service for the backend AI recommendation endpoint.
/// Owns device_id persistence and all networking for /ai/recommend.
/// This is completely isolated from the Occasion system.
///
/// RESILIENT DECODING: Handles both response shapes transparently:
///   - New (cart-aware backend deployed): { "ai_context": "...", "recommendations": [...] }
///   - Old (pre-deploy / fallback):       [ { id, name, price, ... }, ... ]
class RecommendationService {
    static let shared = RecommendationService()

    private let deviceIdKey = "RecoServiceDeviceId"
    private let baseURL = Config.apiBaseURL

    // Reuse the same device_id as RecommendationEngine so backend history is coherent
    var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: deviceIdKey) {
            return id
        }
        // Fall back to RecommendationEngine's device_id if it already exists,
        // so the backend sees a unified user history timeline.
        if let existingId = UserDefaults.standard.string(forKey: "UserDeviceId") {
            UserDefaults.standard.set(existingId, forKey: deviceIdKey)
            return existingId
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: deviceIdKey)
        return newId
    }

    private init() {}

    // MARK: - Cart-Aware Recommendation Fetch

    /// Fetches AI-powered recommendations from the backend.
    /// Sends the current cart contents as the PRIMARY recommendation signal.
    /// - Parameter cartItems: Current cart contents. Empty array triggers trending/popular mode.
    /// - Returns: A tuple of (aiContext, recommendations). aiContext is the backend-generated
    ///   subheading string. Returns ("", []) on network failure so the UI degrades gracefully.
    func fetchRecommendations(cartItems: [CartItem]) async -> (aiContext: String, recommendations: [PairItWithProduct]) {
        guard let url = URL(string: "\(baseURL)/ai/recommend") else {
            print("⚠️ RecommendationService: invalid URL")
            return ("", [])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Build cart_items payload with id, name, category, tags
        let cartPayload: [[String: Any]] = cartItems.map { item in
            var dict: [String: Any] = [
                "id": item.product.id,
                "name": item.product.name
            ]
            if let category = item.product.category { dict["category"] = category }
            if let tags = item.product.tags         { dict["tags"] = tags }
            return dict
        }

        let body: [String: Any] = [
            "device_id": deviceId,
            "cart_items": cartPayload
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            print("⚠️ RecommendationService: failed to serialize request body")
            return ("", [])
        }
        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                print("⚠️ RecommendationService: non-2xx response")
                return ("", [])
            }

            // ── Resilient dual-format decoding ────────────────────────────────
            // Try NEW format first: { "ai_context": "...", "recommendations": [...] }
            // Fall back to OLD format: [...] (flat array, pre-deploy backend)
            return decodeResponse(from: data)

        } catch {
            print("⚠️ RecommendationService network error: \(error.localizedDescription)")
            return ("", [])
        }
    }

    // MARK: - Dual-Format Response Decoder

    private func decodeResponse(from data: Data) -> (aiContext: String, recommendations: [PairItWithProduct]) {
        let decoder = JSONDecoder()

        // Attempt 1 — NEW wrapped format: { ai_context, recommendations }
        if let wrappedResponse = try? decoder.decode(AIRecommendationResponse.self, from: data),
           !wrappedResponse.recommendations.isEmpty {
            print("✅ RecommendationService: decoded NEW wrapped format (\(wrappedResponse.recommendations.count) items), context: \"\(wrappedResponse.aiContext ?? "none")\"")
            let products = mapRawProducts(wrappedResponse.recommendations)
            return (wrappedResponse.aiContext ?? "", products)
        }

        // Attempt 2 — OLD flat array format: [{ id, name, price, ... }]
        if let flatProducts = try? decoder.decode([AIRecommendedProduct].self, from: data),
           !flatProducts.isEmpty {
            print("✅ RecommendationService: decoded OLD flat-array format (\(flatProducts.count) items)")
            let products = mapRawProducts(flatProducts)
            return ("", products)   // No ai_context from old backend — ViewModel will use local fallback
        }

        // Attempt 3 — Log raw response for debugging
        let raw = String(data: data, encoding: .utf8) ?? "<unreadable>"
        print("⚠️ RecommendationService: both decode formats failed. Raw response: \(raw.prefix(500))")
        return ("", [])
    }

    private func mapRawProducts(_ rawProducts: [AIRecommendedProduct]) -> [PairItWithProduct] {
        rawProducts.compactMap { raw in
            // Defensive: skip any product with invalid core data
            guard raw.price >= 0 else { return nil }

            let product = Product(
                id: raw.id,
                name: raw.name,
                price: raw.price,
                description: raw.description,
                imageUrl: raw.imageUrl,
                category: raw.category,
                stock: raw.stock,
                tags: raw.tags,
                aiReasoning: raw.aiReasoning
            )
            return PairItWithProduct(product: product, aiReasoning: raw.aiReasoning)
        }
    }
}

// MARK: - Backend Response Models

/// NEW format (cart-aware backend): { "ai_context": "...", "recommendations": [...] }
private struct AIRecommendationResponse: Decodable {
    let aiContext: String?
    let recommendations: [AIRecommendedProduct]

    enum CodingKeys: String, CodingKey {
        case aiContext = "ai_context"
        case recommendations
    }
}

/// Shared product model — used in both old flat-array and new wrapped responses.
private struct AIRecommendedProduct: Decodable {
    let id: Int
    let name: String
    let price: Double
    let description: String?
    let category: String?
    let stock: Int?
    let aiReasoning: String?
    let tags: [String]?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, price, description, category, stock, tags
        case aiReasoning = "ai_reasoning"
        case imageUrl    = "image_url"
    }
}
