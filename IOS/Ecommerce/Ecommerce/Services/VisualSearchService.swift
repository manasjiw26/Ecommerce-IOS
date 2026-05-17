import Foundation
import UIKit

// MARK: - Response Models

struct VisualSearchResponse: Codable {
    let products: [Product]
    let searchLogId: String?
    let labelsUsed: [String]?

    enum CodingKeys: String, CodingKey {
        case products
        case searchLogId = "search_log_id"
        case labelsUsed  = "labels_used"
    }
}

// MARK: - Service

class VisualSearchService {
    static let shared = VisualSearchService()
    private let baseURL = Config.apiBaseURL
    private init() {}

    /// Sends vision labels + the captured image to the backend and returns matched products.
    func performSearch(
        deviceId: String,
        visionLabels: [(label: String, confidence: Float)],
        topLabel: String,
        image: UIImage,
        mode: String,
        dominantColors: [String] = []
    ) async throws -> VisualSearchResponse {

        guard let url = URL(string: "\(baseURL)/ai/visual-search") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45 // CLIP inference takes a few seconds on server

        let labelsPayload = visionLabels.map { item -> [String: Any] in
            ["label": item.label, "confidence": item.confidence]
        }

        // Compress image to JPEG and base64 encode — keep size small for fast upload
        let base64Image = image
            .jpegData(compressionQuality: 0.5)?
            .base64EncodedString() ?? ""

        let body: [String: Any] = [
            "device_id":      deviceId,
            "vision_labels":  labelsPayload,
            "top_label":      topLabel,
            "base64_image":   base64Image,   // ← CLIP will use this for image similarity
            "mode":           mode,
            "dominant_colors": dominantColors  // ← feeds backend hard color gate (aesthetic mode)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(VisualSearchResponse.self, from: data)
    }

    /// Records thumbs up / thumbs down feedback for a result card.
    func submitFeedback(
        deviceId: String,
        searchLogId: String?,
        productId: Int,
        wasRelevant: Bool
    ) async {
        guard let url = URL(string: "\(baseURL)/ai/visual-search/feedback") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "device_id":   deviceId,
            "product_id":  productId,
            "was_relevant": wasRelevant
        ]
        if let logId = searchLogId { body["search_log_id"] = logId }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        _ = try? await URLSession.shared.data(for: request)
    }
}
