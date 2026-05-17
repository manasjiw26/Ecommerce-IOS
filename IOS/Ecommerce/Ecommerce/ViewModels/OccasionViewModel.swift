import Foundation
import Combine
import CoreML

@MainActor
class OccasionViewModel: ObservableObject {
    @Published var currentOccasion: Occasion? = nil
    
    init() {}
    
    func detectOccasion(from items: [CartItem]) {
        guard !items.isEmpty else {
            currentOccasion = nil
            return
        }
        
        let deviceId = RecommendationEngine.shared.deviceId
        guard let url = URL(string: "\(Config.apiBaseURL)/ai/occasion-detect") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let cartPayload = items.map { item -> [String: Any] in
            var dict: [String: Any] = [
                "product_id": item.product.id,
                "name": item.product.name,
                "category": item.product.category ?? "",
                "price": item.product.price,
                "quantity": item.quantity
            ]
            if let tags = item.product.tags {
                dict["tags"] = tags
            }
            return dict
        }
        
        let body: [String: Any] = [
            "device_id": deviceId,
            "cart_items": cartPayload
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            
            struct BackendOccasionResponse: Codable {
                let label: String
                let title: String?
                let subtitle: String?
                let description: String?
                let background_image_url: String?
                let is_local_asset: Bool?
            }
            
            do {
                let decoded = try JSONDecoder().decode(BackendOccasionResponse.self, from: data)
                DispatchQueue.main.async {
                    let label = decoded.label == "unknown" ? "culinary" : decoded.label
                    let occasion = Occasion(
                        title: decoded.title ?? "YOU MIGHT BE PLANNING",
                        subtitle: decoded.subtitle ?? (label == "culinary" ? "Culinary Masterclass" : label.capitalized),
                        description: decoded.description ?? "Curated specifically for you.",
                        tag: label,
                        backgroundImageUrl: decoded.background_image_url ?? "https://res.cloudinary.com/dl7sh9osm/image/upload/q_auto/f_auto/v1779008584/Gemini_Generated_Image_8vdf6r8vdf6r8vdf.png",
                        isLocalAsset: decoded.is_local_asset ?? false
                    )
                    self?.currentOccasion = occasion
                    RecommendationEngine.shared.searchProducts(query: label)
                }
            } catch {
                print("Failed to decode backend occasion response: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    let occasion = Occasion(
                        title: "YOU MIGHT BE PLANNING",
                        subtitle: "Culinary Masterclass",
                        description: "Professional-grade tools to master new recipes and elevate your kitchen technique.",
                        tag: "culinary",
                        backgroundImageUrl: "https://res.cloudinary.com/dl7sh9osm/image/upload/q_auto/f_auto/v1779008584/Gemini_Generated_Image_8vdf6r8vdf6r8vdf.png",
                        isLocalAsset: false
                    )
                    self?.currentOccasion = occasion
                    RecommendationEngine.shared.searchProducts(query: "culinary")
                }
            }
        }.resume()
    }
}
