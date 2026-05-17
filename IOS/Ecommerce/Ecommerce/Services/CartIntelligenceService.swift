import Foundation

struct CartBundle: Codable, Identifiable {
    var id: String { title }
    let title: String
    let reasoning: String?
    let items: [Product]
}

struct BundleBuildResponse: Codable {
    let seed: [Product]
    let bundles: [CartBundle]
}

struct ResurfaceItem: Codable, Identifiable {
    var id: String { "\(productId)" }
    let productId: Int
    let productName: String
    let reason: String
    let urgency: String?

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case productName = "product_name"
        case reason
        case urgency
    }
}

struct ResurfaceResponse: Codable {
    let resurface: [ResurfaceItem]
    let allSaved: [SavedForLaterItem]

    enum CodingKeys: String, CodingKey {
        case resurface
        case allSaved = "all_saved"
    }
}

struct CartCoachInsight: Codable, Identifiable {
    var id: String { type + ":" + message }
    let type: String
    let message: String
}

struct CartCoachResponse: Codable {
    let score: Int
    let headline: String
    let insights: [CartCoachInsight]
    let topSuggestion: String

    enum CodingKeys: String, CodingKey {
        case score, headline, insights
        case topSuggestion = "top_suggestion"
    }
}

final class CartIntelligenceService {
    static let shared = CartIntelligenceService()
    private let baseURL = Config.apiBaseURL + "/ai"

    private init() {}

    func bundleBuild(cartItems: [CartItem], deviceId: String) async throws -> BundleBuildResponse {
        guard let url = URL(string: "\(baseURL)/bundle-build") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payloadItems: [[String: Any]] = cartItems.map { item in
            [
                "product_id": item.product.id,
                "name": item.product.name,
                "category": item.product.category ?? "",
                "price": item.product.price,
                "tags": item.product.tags ?? [],
                "quantity": item.quantity
            ]
        }

        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "device_id": deviceId,
            "cart_items": payloadItems
        ])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(BundleBuildResponse.self, from: data)
    }

    func resurface(deviceId: String) async throws -> ResurfaceResponse {
        guard let url = URL(string: "\(baseURL)/resurface?device_id=\(deviceId)") else { throw URLError(.badURL) }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ResurfaceResponse.self, from: data)
    }

    func cartCoach(cartItems: [CartItem]) async throws -> CartCoachResponse {
        guard let url = URL(string: "\(baseURL)/cart-coach") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payloadItems: [[String: Any]] = cartItems.map { item in
            [
                "id": item.product.id,
                "name": item.product.name,
                "category": item.product.category ?? "",
                "price": item.product.price,
                "item_tag": (item.product.tags ?? []).first ?? ""
            ]
        }

        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "cart_items": payloadItems
        ])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CartCoachResponse.self, from: data)
    }
}

