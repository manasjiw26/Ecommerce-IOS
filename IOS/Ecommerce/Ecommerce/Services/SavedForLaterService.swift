import Foundation

struct SavedForLaterItem: Codable, Identifiable {
    let id: String
    let savedAt: String?
    let product: Product?

    enum CodingKeys: String, CodingKey {
        case id
        case savedAt = "saved_at"
        case product
    }
}

final class SavedForLaterService {
    static let shared = SavedForLaterService()
    private let baseURL = Config.apiBaseURL + "/cart"

    private init() {}

    func save(deviceId: String, productId: Int) async throws {
        guard let url = URL(string: "\(baseURL)/save-for-later") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "device_id": deviceId,
            "product_id": productId
        ])

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func remove(deviceId: String, productId: Int) async throws {
        guard let url = URL(string: "\(baseURL)/save-for-later") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "device_id": deviceId,
            "product_id": productId
        ])

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func list(deviceId: String) async throws -> [SavedForLaterItem] {
        guard let url = URL(string: "\(baseURL)/saved/\(deviceId)") else { throw URLError(.badURL) }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([SavedForLaterItem].self, from: data)
    }
}

