import Foundation

struct RegistryDashboardResponse: Codable {
    let registry: Registry
    let stats: RegistryStats
    let items: [RegistryItem]
}

struct RegistryStats: Codable {
    let totalItems: Int
    let purchasedItems: Int
    let pendingItems: Int
    let budgetTotal: Double
    let budgetUsed: Double
    let budgetRemaining: Double
    let completionPct: Int
    let daysUntilEvent: Int?
    
    enum CodingKeys: String, CodingKey {
        case totalItems = "total_items"
        case purchasedItems = "purchased_items"
        case pendingItems = "pending_items"
        case budgetTotal = "budget_total"
        case budgetUsed = "budget_used"
        case budgetRemaining = "budget_remaining"
        case completionPct = "completion_pct"
        case daysUntilEvent = "days_until_event"
    }
}

struct GroupContributionResponse: Codable {
    let totalContributed: Double
    let targetAmount: Double
    let isFullyFunded: Bool
    
    enum CodingKeys: String, CodingKey {
        case totalContributed = "total_contributed"
        case targetAmount = "target_amount"
        case isFullyFunded = "is_fully_funded"
    }
}

class RegistryService {
    static let shared = RegistryService()
    private let baseURL = Config.apiBaseURL + "/registry"
    
    func fetchUserRegistries(userId: String) async throws -> [Registry] {
        guard let url = URL(string: "\(baseURL)/user/\(userId)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([Registry].self, from: data)
    }
    
    func fetchRegistryDashboard(registryId: String) async throws -> RegistryDashboardResponse {
        guard let url = URL(string: "\(baseURL)/\(registryId)/dashboard") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(RegistryDashboardResponse.self, from: data)
    }
    
    func createRegistry(dto: RegistryCreationDTO) async throws -> Registry {
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(dto)
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Registry.self, from: data)
    }
    
    func updateRegistry(registryId: String, name: String, date: String, location: String) async throws -> Registry {
        guard let putUrl = URL(string: "\(baseURL)/\(registryId)") else { throw URLError(.badURL) }
        var request = URLRequest(url: putUrl)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "theme": name,
            "event_date": date,
            "event_location": location
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Registry.self, from: data)
    }
    
    func deleteRegistry(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/\(id)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 15
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    func fetchRegistryItems(registryId: String) async throws -> [RegistryItem] {
        guard let url = URL(string: "\(baseURL)/\(registryId)/items") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([RegistryItem].self, from: data)
    }
    
    func addItemToRegistry(registryId: String, productId: Int, quantity: Int = 1, isMostWanted: Bool = false, aiReason: String? = nil) async throws -> RegistryItem {
        guard let url = URL(string: "\(baseURL)/\(registryId)/items") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "product_id": productId,
            "quantity_requested": quantity,
            "is_most_wanted": isMostWanted
        ]
        if let reason = aiReason {
            body["ai_reason"] = reason
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(RegistryItem.self, from: data)
    }
    
    func updateRegistryItem(registryId: String, itemId: String, updates: [String: Any]) async throws -> RegistryItem {
        guard let url = URL(string: "\(baseURL)/\(registryId)/items/\(itemId)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: updates)
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(RegistryItem.self, from: data)
    }
    
    func deleteRegistryItem(registryId: String, itemId: String) async throws {
        guard let url = URL(string: "\(baseURL)/\(registryId)/items/\(itemId)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 15
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    func joinRegistryByCode(code: String) async throws -> Registry? {
        guard let encodedCode = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/public/\(encodedCode)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode == 404 || httpResponse.statusCode == 500 {
            return nil
        }
        
        let dashboard = try JSONDecoder().decode(RegistryDashboardResponse.self, from: data)
        return dashboard.registry
    }
    
    func addAlternativeGift(registryId: String, productId: Int) async throws -> RegistryItem {
        // Surprise gifts have quantity_requested = 0
        return try await addItemToRegistry(
            registryId: registryId,
            productId: productId,
            quantity: 0,
            isMostWanted: false,
            aiReason: "Gifted as surprise by Guest"
        )
    }
    
    func contributeToGroupGift(registryId: String, itemId: String, contributorName: String, amount: Double, message: String?) async throws -> GroupContributionResponse {
        guard let url = URL(string: "\(baseURL)/\(registryId)/contribute") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "registry_item_id": itemId,
            "contributor_name": contributorName,
            "amount": amount,
            "message": message ?? ""
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(GroupContributionResponse.self, from: data)
    }
}
