import Foundation
import Combine

class RecommendationEngine: ObservableObject {
    static let shared = RecommendationEngine()
    
    @Published var mostViewedCategory: String?
    
    private let saveKey = "UserCategoryViews"
    
    init() {
        loadMostViewed()
    }
    
    func logView(for category: String) {
        var views = getViews()
        views[category, default: 0] += 1
        
        if let encoded = try? JSONEncoder().encode(views) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
        
        loadMostViewed()
    }
    
    private func getViews() -> [String: Int] {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            return decoded
        }
        return [:]
    }
    
    private func loadMostViewed() {
        let views = getViews()
        self.mostViewedCategory = views.max { a, b in a.value < b.value }?.key
    }
}
