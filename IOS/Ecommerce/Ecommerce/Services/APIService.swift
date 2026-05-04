import Foundation

class APIService {
    static let shared = APIService()
    static let baseURL = "http://localhost:3000"
    private let baseURL_instance = APIService.baseURL
    
    func fetchProducts() async throws -> [Product] {
        guard let url = URL(string: "\(APIService.baseURL)/products") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Product].self, from: data)
    }
}
