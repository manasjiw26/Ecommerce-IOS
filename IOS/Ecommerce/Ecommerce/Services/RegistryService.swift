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

struct RegistryShareLinkResponse: Codable {
    let shareToken: String
    let shareUrl: String

    enum CodingKeys: String, CodingKey {
        case shareToken = "share_token"
        case shareUrl = "share_url"
    }
}

struct RegistryAPIError: Codable {
    let error: String?
    let code: Int?
}

class RegistryService {
    static let shared = RegistryService()
    private let baseURL = Config.apiBaseURL + "/registry"
    
    // MARK: - Reusable Private Request Helper with JWT Authentication
    
    private func makeRequest(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        
        if method == "POST" || method == "PUT" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        if let token = AuthSession.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔑 RegistryService: Attaching Bearer auth token.")
        } else {
            print("⚠️ RegistryService: No active Auth token found.")
        }
        
        return request
    }
    
    // MARK: - API Methods
    
    func fetchUserRegistries(userId: String) async throws -> [Registry] {
        guard let url = URL(string: "\(baseURL)/user/\(userId)") else { throw URLError(.badURL) }
        print("🌐 RegistryService: GET \(url.absoluteString)")
        let request = makeRequest(url: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        print("RES: fetchUserRegistries statusCode=\(httpResponse.statusCode)")
        guard httpResponse.statusCode == 200 else {
            let apiErr = try? JSONDecoder().decode(RegistryAPIError.self, from: data)
            print("❌ RegistryService error: \(apiErr?.error ?? "Unknown")")
            throw NSError(domain: "RegistryService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: apiErr?.error ?? "Failed to load registries (\(httpResponse.statusCode))"])
        }
        
        do {
            let registries = try JSONDecoder().decode([Registry].self, from: data)
            print("✅ RegistryService: Decoded \(registries.count) registries successfully")
            return registries
        } catch {
            print("❌ RegistryService: Error decoding registries: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("❌ Raw JSON response: \(jsonString)")
            }
            throw error
        }
    }
    
    func fetchRegistryDashboard(registryId: String) async throws -> RegistryDashboardResponse {
        guard let url = URL(string: "\(baseURL)/\(registryId)/dashboard") else { throw URLError(.badURL) }
        print("🌐 RegistryService: GET \(url.absoluteString)")
        let request = makeRequest(url: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        print("RES: fetchRegistryDashboard statusCode=\(httpResponse.statusCode)")
        guard httpResponse.statusCode == 200 else {
            let apiErr = try? JSONDecoder().decode(RegistryAPIError.self, from: data)
            print("❌ RegistryService error: \(apiErr?.error ?? "Unknown")")
            throw NSError(domain: "RegistryService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: apiErr?.error ?? "Failed to load dashboard (\(httpResponse.statusCode))"])
        }
        
        do {
            let dashboard = try JSONDecoder().decode(RegistryDashboardResponse.self, from: data)
            print("✅ RegistryService: Decoded dashboard successfully")
            return dashboard
        } catch {
            print("❌ RegistryService: Error decoding dashboard: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("❌ Raw JSON response: \(jsonString)")
            }
            throw error
        }
    }
    
    func createRegistry(dto: RegistryCreationDTO) async throws -> Registry {
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        print("🌐 RegistryService: POST \(url.absoluteString)")
        let dtoData = try JSONEncoder().encode(dto)
        let request = makeRequest(url: url, method: "POST", body: dtoData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        print("RES: createRegistry statusCode=\(httpResponse.statusCode)")
        guard httpResponse.statusCode == 200 else {
            let apiErr = try? JSONDecoder().decode(RegistryAPIError.self, from: data)
            throw NSError(domain: "RegistryService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: apiErr?.error ?? "Failed to create registry (\(httpResponse.statusCode))"])
        }
        return try JSONDecoder().decode(Registry.self, from: data)
    }
    
    func updateRegistry(registryId: String, name: String, date: String, location: String) async throws -> Registry {
        guard let putUrl = URL(string: "\(baseURL)/\(registryId)") else { throw URLError(.badURL) }
        print("🌐 RegistryService: PUT \(putUrl.absoluteString)")
        let body: [String: Any] = [
            "theme": name,
            "event_date": date,
            "event_location": location
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = makeRequest(url: putUrl, method: "PUT", body: bodyData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Registry.self, from: data)
    }
    
    func deleteRegistry(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/\(id)") else { throw URLError(.badURL) }
        print("🌐 RegistryService: DELETE \(url.absoluteString)")
        let request = makeRequest(url: url, method: "DELETE")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    func fetchRegistryItems(registryId: String) async throws -> [RegistryItem] {
        guard let url = URL(string: "\(baseURL)/\(registryId)/items") else { throw URLError(.badURL) }
        print("🌐 RegistryService: GET \(url.absoluteString)")
        let request = makeRequest(url: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([RegistryItem].self, from: data)
    }
    
    func addItemToRegistry(registryId: String, productId: Int, quantity: Int = 1, isMostWanted: Bool = false, aiReason: String? = nil) async throws -> RegistryItem {
        guard let url = URL(string: "\(baseURL)/\(registryId)/items") else { throw URLError(.badURL) }
        print("🌐 RegistryService: POST \(url.absoluteString)")
        var body: [String: Any] = [
            "product_id": productId,
            "quantity_requested": quantity,
            "is_most_wanted": isMostWanted
        ]
        if let reason = aiReason {
            body["ai_reason"] = reason
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = makeRequest(url: url, method: "POST", body: bodyData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        print("RES: addItemToRegistry statusCode=\(httpResponse.statusCode)")
        guard httpResponse.statusCode == 200 else {
            let apiError = try? JSONDecoder().decode(RegistryAPIError.self, from: data)
            throw NSError(
                domain: "RegistryService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: apiError?.error ?? "Failed to add product to registry."]
            )
        }
        return try JSONDecoder().decode(RegistryItem.self, from: data)
    }
    
    func updateRegistryItem(registryId: String, itemId: String, updates: [String: Any]) async throws -> RegistryItem {
        guard let url = URL(string: "\(baseURL)/\(registryId)/items/\(itemId)") else { throw URLError(.badURL) }
        print("🌐 RegistryService: PUT \(url.absoluteString)")
        let bodyData = try JSONSerialization.data(withJSONObject: updates)
        let request = makeRequest(url: url, method: "PUT", body: bodyData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(RegistryItem.self, from: data)
    }
    
    func deleteRegistryItem(registryId: String, itemId: String) async throws {
        guard let url = URL(string: "\(baseURL)/\(registryId)/items/\(itemId)") else { throw URLError(.badURL) }
        print("🌐 RegistryService: DELETE \(url.absoluteString)")
        let request = makeRequest(url: url, method: "DELETE")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    func joinRegistryByCode(code: String) async throws -> RegistryDashboardResponse? {
        guard let encodedCode = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/public/\(encodedCode)") else { throw URLError(.badURL) }
        print("🌐 RegistryService: GET \(url.absoluteString)")
        let request = makeRequest(url: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode == 404 || httpResponse.statusCode == 500 {
            return nil
        }
        
        return try JSONDecoder().decode(RegistryDashboardResponse.self, from: data)
    }

    func searchRegistriesByName(_ name: String) async throws -> [Registry] {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search?name=\(encoded)") else { throw URLError(.badURL) }
        print("🌐 RegistryService: GET \(url.absoluteString)")
        let request = makeRequest(url: url)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([Registry].self, from: data)
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
        print("🌐 RegistryService: POST \(url.absoluteString)")
        let body: [String: Any] = [
            "registry_item_id": itemId,
            "contributor_name": contributorName,
            "amount": amount,
            "message": message ?? ""
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = makeRequest(url: url, method: "POST", body: bodyData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(GroupContributionResponse.self, from: data)
    }

    func fetchShareLink(registryId: String) async throws -> RegistryShareLinkResponse {
        guard let url = URL(string: "\(baseURL)/\(registryId)/share-link") else { throw URLError(.badURL) }
        print("🌐 RegistryService: GET \(url.absoluteString)")
        let request = makeRequest(url: url)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(RegistryShareLinkResponse.self, from: data)
    }
    
    func addCollaborator(registryId: String, email: String, role: String = "viewer") async throws {
        guard let url = URL(string: "\(baseURL)/\(registryId)/collaborators") else { throw URLError(.badURL) }
        print("🌐 RegistryService: POST \(url.absoluteString)")
        let body = ["email": email, "role": role]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = makeRequest(url: url, method: "POST", body: bodyData)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
}
