import Foundation

class APIService {
    static let shared = APIService()
    static let baseURL = Config.apiBaseURL
    private let baseURL_instance = APIService.baseURL
    
    func fetchProducts() async throws -> [Product] {
        guard let url = URL(string: "\(APIService.baseURL)/products") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 60 // Wait up to 60s for Render to wake up
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Product].self, from: data)
    }
}
