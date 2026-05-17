import Foundation
import Combine

struct MockRegistryExtended: Identifiable, Hashable {
    let id: String
    var code: String // Unique short code for sharing/joining (maps to share_token)
    var name: String // maps to theme
    var type: String // maps to event_type
    var date: String // maps to event_date
    var location: String // maps to event_location
    var bannerImageUrl: String
    var itemsCount: Int
    var isOwner: Bool
    var eventStory: String
    var isAnonymousGiftingAllowed: Bool
    var shipDirectlyToRegistrant: Bool
}

struct SmartBundleOption: Identifiable, Hashable, Codable {
    var id: UUID { UUID() }
    let title: String
    let subtitle: String
    let imageUrl: String
    let bundleType: String
    let productIds: [Int]?

    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case imageUrl
        case bundleType
        case productIds
    }

    init(title: String, subtitle: String, imageUrl: String, bundleType: String, productIds: [Int]? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.imageUrl = imageUrl
        self.bundleType = bundleType
        self.productIds = productIds
    }
}

class MockRegistryService: ObservableObject {
    static let shared = MockRegistryService()
    
    @Published var registries: [MockRegistryExtended] = []
    @Published var registryItems: [String: [RegistryItem]] = [:]
    @Published var starterBundles: [SmartBundleOption] = []
    
    private init() {
        // Mock arrays initialized empty; all loaded dynamically from Supabase at runtime!
        self.registries = []
        self.registryItems = [:]
        self.starterBundles = []
    }
    
    // MARK: - Live Supabase Backend Fetch Routines
    
    @MainActor
    func fetchRegistriesFromBackend() async throws {
        guard let currentUserId = AuthSession.shared.currentUser?.id else {
            print("❌ MockRegistryService.fetchRegistriesFromBackend: No current user ID, returning early.")
            self.registries = []
            self.registryItems = [:]
            return
        }
        
        print("🔍 MockRegistryService.fetchRegistriesFromBackend: Fetching for user \(currentUserId)")
        let loaded = try await RegistryService.shared.fetchUserRegistries(userId: currentUserId)
        print("✅ MockRegistryService.fetchRegistriesFromBackend: Loaded \(loaded.count) registries")
        var extendedList: [MockRegistryExtended] = []
        
        for reg in loaded {
            var ext = reg.toExtended(currentUserId: currentUserId)
            do {
                let dashboard = try await RegistryService.shared.fetchRegistryDashboard(registryId: reg.id)
                ext.itemsCount = dashboard.items.count
                self.registryItems[reg.id] = dashboard.items
            } catch {
                ext.itemsCount = 0
                self.registryItems[reg.id] = []
            }
            extendedList.append(ext)
        }
        
        // Merge: keep locally-joined registries that the backend hasn't returned yet
        let backendIds = Set(extendedList.map { $0.id })
        let localOnly = self.registries.filter { !backendIds.contains($0.id) }
        self.registries = extendedList + localOnly
    }
    
    @MainActor
    func fetchRegistryDashboard(registryId: String) async throws {
        let response = try await RegistryService.shared.fetchRegistryDashboard(registryId: registryId)
        
        self.registryItems[registryId] = response.items
        
        if let idx = registries.firstIndex(where: { $0.id == registryId }) {
            registries[idx].itemsCount = response.items.count
            registries[idx].name = response.registry.theme ?? registries[idx].name
            registries[idx].date = RegistryDateFormatter.displayString(from: response.registry.eventDate)
            registries[idx].location = response.registry.eventLocation ?? "N/A"
            registries[idx].code = response.registry.shareToken ?? registries[idx].code
        }
    }
    
    func fetchStarterBundles(eventType: String) async {
        guard let url = URL(string: "\(Config.apiBaseURL)/registry/starter-bundles?event_type=\(eventType.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? eventType)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([SmartBundleOption].self, from: data)
            await MainActor.run {
                self.starterBundles = decoded
            }
        } catch {
            print("❌ Failed to decode starter bundles from backend: \(error)")
        }
    }
    
    func fetchProductById(pid: Int) async throws -> Product {
        guard let url = URL(string: "\(Config.apiBaseURL)/products/\(pid)") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Product.self, from: data)
    }
    
    // MARK: - Context-Aware Image Generation Helper (Western & Casual Indian)
    
    func getContextAwareBannerImage(eventName: String, eventType: String) -> String {
        let nameLower = eventName.lowercased()
        let typeLower = eventType.lowercased()
        
        if (nameLower.contains("indian") && nameLower.contains("wedding")) || (typeLower.contains("indian") && typeLower.contains("wedding")) {
            return "https://images.unsplash.com/photo-1583939003579-730e3918a45a?auto=format&fit=crop&w=1200&q=80"
        } else if nameLower.contains("wedding") || nameLower.contains("marriage") || typeLower.contains("wedding") {
            return "https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1200&q=80"
        } else if (nameLower.contains("indian") && nameLower.contains("engagement")) || (typeLower.contains("indian") && typeLower.contains("engagement")) {
            return "https://images.unsplash.com/photo-1607190074257-dd4b7af0309f?auto=format&fit=crop&w=1200&q=80"
        } else if nameLower.contains("engagement") || typeLower.contains("engagement") {
            return "https://images.unsplash.com/photo-1515934751635-c81c6bc9a2d8?auto=format&fit=crop&w=1200&q=80"
        } else if nameLower.contains("sangeet") || typeLower.contains("sangeet") {
            return "https://images.unsplash.com/photo-1610030469983-98e550d6193c?auto=format&fit=crop&w=1200&q=80"
        } else if nameLower.contains("diwali") || typeLower.contains("diwali") {
            return "https://images.unsplash.com/photo-1545224825-9e7ecf2e46b9?auto=format&fit=crop&w=1200&q=80"
        } else if (nameLower.contains("indian") && nameLower.contains("gathering")) || typeLower.contains("gathering") {
            return "https://images.unsplash.com/photo-1601050690597-df056fb4ce78?auto=format&fit=crop&w=1200&q=80"
        } else if nameLower.contains("western dinner") || typeLower.contains("western dinner") || typeLower.contains("western dinner party") {
            return "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=1200&q=80"
        } else if nameLower.contains("brunch") || typeLower.contains("brunch") {
            return "https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=1200&q=80"
        } else if nameLower.contains("house") || nameLower.contains("warming") || nameLower.contains("home") || typeLower.contains("housewarming") {
            return "https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1200&q=80"
        } else if nameLower.contains("baby") || nameLower.contains("shower") || typeLower.contains("baby") {
            return "https://images.unsplash.com/photo-1519689680058-324335c77ebe?auto=format&fit=crop&w=1200&q=80"
        } else if nameLower.contains("bridal") || typeLower.contains("bridal") {
            return "https://images.unsplash.com/photo-1469371670807-013ccf25f16a?auto=format&fit=crop&w=1200&q=80"
        } else if nameLower.contains("birthday") || nameLower.contains("celebrate") || nameLower.contains("bday") || typeLower.contains("birthday") {
            return "https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?auto=format&fit=crop&w=1200&q=80"
        } else if nameLower.contains("gala") || nameLower.contains("dinner") || nameLower.contains("cocktail") || typeLower.contains("gala") || typeLower.contains("dinner") {
            return "https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?auto=format&fit=crop&w=1200&q=80"
        } else {
            return "https://images.unsplash.com/photo-1465495976277-4387d4b0b4c6?auto=format&fit=crop&w=1200&q=80"
        }
    }

    func buildEventStory(theme: String?, eventType: String) -> String {
        let base = theme?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (base?.isEmpty == false) ? base! : "Our Celebration"
        return "\(name) is coming up — we’re celebrating \(eventType). Thank you for helping us build our home together."
    }
    
    // MARK: - Smart Starter Bundle Options based on Event Type
    
    func getSmartBundlesForEvent(type: String) -> [SmartBundleOption] {
        let t = type.lowercased()
        if t.contains("sangeet") || t.contains("diwali") {
            return [
                SmartBundleOption(
                    title: "Festive Host Starter",
                    subtitle: "Premium traditional platters & servers",
                    imageUrl: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Festive Host"
                ),
                SmartBundleOption(
                    title: "Royal Dining Essentials",
                    subtitle: "Elegant brass & copper serving styles",
                    imageUrl: "https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Royal Dining"
                )
            ]
        } else if t.contains("wedding") || t.contains("engagement") {
            return [
                SmartBundleOption(
                    title: "Grand Kitchen Starter",
                    subtitle: "Luxury enameled cast iron & appliances",
                    imageUrl: "https://images.unsplash.com/photo-1584269600464-37b1b58a9fe7?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Grand Kitchen"
                ),
                SmartBundleOption(
                    title: "Crystal Tabletop",
                    subtitle: "Premium Schott Zwiesel glassware & wine styles",
                    imageUrl: "https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Crystal Tabletop"
                )
            ]
        } else if t.contains("housewarming") {
            return [
                SmartBundleOption(
                    title: "New Nest Essentials",
                    subtitle: "Cozy mugs, organic linens & woodware",
                    imageUrl: "https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=300&q=80",
                    bundleType: "New Nest"
                ),
                SmartBundleOption(
                    title: "Premium Barware",
                    subtitle: "Cocktail tools & marble serving boards",
                    imageUrl: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Premium Barware"
                )
            ]
        } else if t.contains("baby") || t.contains("bridal") {
            return [
                SmartBundleOption(
                    title: "High Tea Celebration",
                    subtitle: "Charming teapots, cups & tier stands",
                    imageUrl: "https://images.unsplash.com/photo-1469371670807-013ccf25f16a?auto=format&fit=crop&w=300&q=80",
                    bundleType: "High Tea"
                ),
                SmartBundleOption(
                    title: "Baking Starter Bundle",
                    subtitle: "Premium mixers & ceramic baking dishes",
                    imageUrl: "https://images.unsplash.com/photo-1584269600464-37b1b58a9fe7?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Baking Starter"
                )
            ]
        } else {
            return [
                SmartBundleOption(
                    title: "Professional Mixology",
                    subtitle: "Barware tools, strainers & luxury glassware",
                    imageUrl: "https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Professional Mixology"
                ),
                SmartBundleOption(
                    title: "Gourmet Entertaining",
                    subtitle: "Cheeseboards, marble platters & markers",
                    imageUrl: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Gourmet Entertaining"
                )
            ]
        }
    }
    
    // MARK: - Smart Starter Bundle execution using REAL database products
    
    func applySmartBundle(registryId: String, bundleType: String) async throws {
        var productsToAdd: [Product] = []
        let catalogProducts = (try? await APIService.shared.fetchProducts()) ?? []
        
        // Try to find the bundle dynamically from the backend fetched list first
        if let matchingBundle = starterBundles.first(where: { $0.bundleType == bundleType }),
           let pIds = matchingBundle.productIds, !pIds.isEmpty {
            
            for pid in pIds {
                if let found = catalogProducts.first(where: { $0.id == pid }) {
                    productsToAdd.append(found)
                } else if let fetched = try? await fetchProductById(pid: pid) {
                    productsToAdd.append(fetched)
                }
            }
        }
        
        // Fallback to backend catalog matches if the bundle had no product ids.
        if productsToAdd.isEmpty {
            let typeLower = bundleType.lowercased()
            
            if typeLower.contains("festive") || typeLower.contains("royal") || typeLower.contains("barware") || typeLower.contains("entertaining") || typeLower.contains("mixology") || typeLower.contains("glassware") {
                let filtered = catalogProducts.filter {
                    let name = $0.name.lowercased()
                    let cat = ($0.category ?? "").lowercased()
                    return name.contains("glass") || name.contains("wine") || name.contains("appetizer") || name.contains("platter") || name.contains("board") || name.contains("cheese") || cat.contains("table") || cat.contains("bar") || cat.contains("din")
                }
                productsToAdd = Array((filtered.isEmpty ? catalogProducts : filtered).prefix(2))
            } else {
                let filtered = catalogProducts.filter {
                    let name = $0.name.lowercased()
                    let cat = ($0.category ?? "").lowercased()
                    return name.contains("pan") || name.contains("pot") || name.contains("chef") || name.contains("knife") || name.contains("oven") || name.contains("bake") || name.contains("mixer") || cat.contains("cook") || cat.contains("appl") || cat.contains("cut")
                }
                productsToAdd = Array((filtered.isEmpty ? catalogProducts : filtered).prefix(2))
            }
        }

        guard !productsToAdd.isEmpty else {
            throw NSError(domain: "Registry", code: 404, userInfo: [NSLocalizedDescriptionKey: "No catalog products are available for this starter bundle."])
        }
        
        for prod in productsToAdd {
            _ = try await RegistryService.shared.addItemToRegistry(
                registryId: registryId,
                productId: prod.id,
                quantity: 1,
                isMostWanted: false,
                aiReason: "Starter bundle \(bundleType)"
            )
        }
        try await self.fetchRegistryDashboard(registryId: registryId)
    }
    
    // MARK: - Add Custom Product to Registry
    
    func addProductToRegistry(registryId: String, product: Product) async throws {
        _ = try await RegistryService.shared.addItemToRegistry(
            registryId: registryId,
            productId: product.id,
            quantity: 1,
            isMostWanted: false,
            aiReason: "Selected from catalog"
        )
        try await self.fetchRegistryDashboard(registryId: registryId)
    }
    
    // MARK: - CRUD & Tag Toggles
    
    func createRegistry(name: String, type: String, isoDate: String, location: String) async throws -> MockRegistryExtended {
        guard let currentUserId = AuthSession.shared.currentUser?.id else {
            throw NSError(domain: "Registry", code: 401, userInfo: [NSLocalizedDescriptionKey: "You must be logged in to create a registry."])
        }
        
        let dto = RegistryCreationDTO(
            userId: currentUserId,
            eventType: type,
            eventDate: isoDate,
            eventLocation: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location,
            isPublic: true,
            theme: name,
            budget: nil
        )
        
        let created = try await RegistryService.shared.createRegistry(dto: dto)
        let extended = created.toExtended(currentUserId: currentUserId)
        
        await MainActor.run {
            self.registries.insert(extended, at: 0)
            self.registryItems[created.id] = []
        }
        
        return extended
    }
    
    func updateRegistry(id: String, name: String, date: String, location: String) {
        Task {
            do {
                let dateForApi = RegistryDateFormatter.isoDateString(fromDisplayString: date) ?? date
                _ = try await RegistryService.shared.updateRegistry(
                    registryId: id,
                    name: name,
                    date: dateForApi,
                    location: location
                )
                try await self.fetchRegistryDashboard(registryId: id)
            } catch {
                print("Error updating registry metadata: \(error)")
            }
        }
    }
    
    func deleteRegistry(id: String) {
        Task {
            do {
                try await RegistryService.shared.deleteRegistry(id: id)
                await MainActor.run {
                    self.registries.removeAll { $0.id == id }
                    self.registryItems.removeValue(forKey: id)
                }
            } catch {
                print("Error deleting registry: \(error)")
            }
        }
    }
    
    func removeItem(registryId: String, itemId: String) {
        Task {
            do {
                try await RegistryService.shared.deleteRegistryItem(registryId: registryId, itemId: itemId)
                try await self.fetchRegistryDashboard(registryId: registryId)
            } catch {
                print("Error deleting registry item: \(error)")
            }
        }
    }
    
    func addAlternativeGift(registryId: String, product: Product) {
        Task {
            do {
                _ = try await RegistryService.shared.addAlternativeGift(registryId: registryId, productId: product.id)
                try await self.fetchRegistryDashboard(registryId: registryId)
            } catch {
                print("Error adding surprise gift: \(error)")
            }
        }
    }
    
    func toggleMostWanted(registryId: String, itemId: String) {
        guard let items = registryItems[registryId],
              let item = items.first(where: { $0.id == itemId }) else { return }
        
        let targetMostWantedVal = !item.isMostWanted
        
        Task {
            do {
                // Single Most Wanted constraint logic:
                // If setting this item to true, clear any other most wanted item in this registry first on backend
                if targetMostWantedVal {
                    for other in items {
                        if other.isMostWanted && other.id != itemId {
                            _ = try await RegistryService.shared.updateRegistryItem(
                                registryId: registryId,
                                itemId: other.id,
                                updates: ["is_most_wanted": false]
                            )
                        }
                    }
                }
                
                // Toggle the target item
                _ = try await RegistryService.shared.updateRegistryItem(
                    registryId: registryId,
                    itemId: itemId,
                    updates: ["is_most_wanted": targetMostWantedVal]
                )
                
                try await self.fetchRegistryDashboard(registryId: registryId)
            } catch {
                print("Error toggling most wanted: \(error)")
            }
        }
    }
    
    func toggleGroupGift(registryId: String, itemId: String) {
        guard let items = registryItems[registryId],
              let item = items.first(where: { $0.id == itemId }) else { return }
        
        let newVal = !(item.isGroupGift ?? false)
        
        Task {
            do {
                _ = try await RegistryService.shared.updateRegistryItem(
                    registryId: registryId,
                    itemId: itemId,
                    updates: ["is_group_gift": newVal]
                )
                try await self.fetchRegistryDashboard(registryId: registryId)
            } catch {
                print("Error toggling group gift: \(error)")
            }
        }
    }
    
    func joinRegistryByCode(code: String) async throws -> MockRegistryExtended? {
        guard let dashboard = try await RegistryService.shared.joinRegistryByCode(code: code) else {
            return nil
        }
        
        // If user is logged in, register them as a collaborator so it appears in "Registries I'm Gifting"
        if let email = AuthSession.shared.currentUser?.email {
            do {
                try await RegistryService.shared.addCollaborator(registryId: dashboard.registry.id, email: email, role: "viewer")
            } catch {
                print("Warning: Failed to add collaborator for joined registry - \(error)")
            }
        }

        var extended = dashboard.registry.toExtended(currentUserId: AuthSession.shared.currentUser?.id)
        extended.itemsCount = dashboard.items.count

        await MainActor.run {
            self.registryItems[dashboard.registry.id] = dashboard.items

            if let idx = self.registries.firstIndex(where: { $0.id == dashboard.registry.id }) {
                self.registries[idx] = extended
            } else {
                self.registries.append(extended)
            }
        }

        return extended
    }
}

// MARK: - Helper Mapping Extension

extension Registry {
    func toExtended(currentUserId: String?) -> MockRegistryExtended {
        let bannerImage = MockRegistryService.shared.getContextAwareBannerImage(
            eventName: self.theme ?? "Celebration",
            eventType: self.eventType
        )
        
        let isOwnerVal = (currentUserId != nil && self.userId == currentUserId)
        
        return MockRegistryExtended(
            id: self.id,
            code: self.shareToken ?? "",
            name: self.theme ?? "\(self.eventType) Celebration",
            type: self.eventType,
            date: RegistryDateFormatter.displayString(from: self.eventDate),
            location: self.eventLocation ?? "N/A",
            bannerImageUrl: bannerImage,
            itemsCount: 0, // Filled in dashboard fetch
            isOwner: isOwnerVal,
            eventStory: MockRegistryService.shared.buildEventStory(theme: self.theme, eventType: self.eventType),
            isAnonymousGiftingAllowed: true,
            shipDirectlyToRegistrant: true
        )
    }
}

// MARK: - Date Formatting

enum RegistryDateFormatter {
    static func displayString(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return input }

        let display = DateFormatter()
        display.locale = Locale(identifier: "en_US_POSIX")
        display.dateFormat = "MMM d, yyyy"

        if let d = parseDate(trimmed) {
            return display.string(from: d)
        }
        return input
    }

    static func isoDateString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    static func isoDateString(fromDisplayString s: String) -> String? {
        let display = DateFormatter()
        display.locale = Locale(identifier: "en_US_POSIX")
        display.dateFormat = "MMM d, yyyy"
        if let d = display.date(from: s.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return isoDateString(from: d)
        }
        return nil
    }

    private static func parseDate(_ s: String) -> Date? {
        let isoDay = DateFormatter()
        isoDay.locale = Locale(identifier: "en_US_POSIX")
        isoDay.dateFormat = "yyyy-MM-dd"
        if let d = isoDay.date(from: s) { return d }

        let isoWithTime = ISO8601DateFormatter()
        if let d = isoWithTime.date(from: s) { return d }

        return nil
    }
}
