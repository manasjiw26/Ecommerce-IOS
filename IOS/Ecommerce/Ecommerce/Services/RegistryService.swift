import Foundation

class RegistryService {
    static let shared = RegistryService()
    private let baseURL = Config.apiBaseURL + "/registry"
    
    func fetchUserRegistries(userId: String) async throws -> [Registry] {
        guard let url = URL(string: "\(baseURL)/user/\(userId)") else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([Registry].self, from: data)
    }
    
    func createRegistry(dto: RegistryCreationDTO) async throws -> Registry {
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(dto)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Registry.self, from: data)
    }
    
    func fetchRegistryItems(registryId: String) async throws -> [RegistryItem] {
        guard let url = URL(string: "\(baseURL)/\(registryId)/items") else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([RegistryItem].self, from: data)
    }
    
    func addItemToRegistry(registryId: String, productId: Int, quantity: Int = 1) async throws -> RegistryItem {
        guard let url = URL(string: "\(baseURL)/\(registryId)/items") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "product_id": productId,
            "quantity_requested": quantity,
            "is_most_wanted": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(RegistryItem.self, from: data)
    }
}
