import Foundation
import Combine

class RecommendationEngine: ObservableObject {
    static let shared = RecommendationEngine()
    
    @Published var recommendedProducts: [Product] = []
    
    private let deviceIdKey = "UserDeviceId"
    
    // Defaulting to localhost, assuming backend is running locally.
    // If deployed, this should point to your Render/Railway backend URL.
    private let baseURL = "http://localhost:3000/ai"
    
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
        // Fetch initially
        fetchRecommendations()
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
                self.fetchRecommendations()
            }
        }.resume()
    }
    
    func fetchRecommendations() {
        guard let url = URL(string: "\(baseURL)/recommend") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["device_id": deviceId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                do {
                    let decoder = JSONDecoder()
                    let products = try decoder.decode([Product].self, from: data)
                    DispatchQueue.main.async {
                        self.recommendedProducts = products
                    }
                } catch {
                    print("Failed to decode recommendations: \(error)")
                }
            }
        }.resume()
    }
}
