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
        let currentUserId = AuthSession.shared.currentUser?.id ?? "00000000-0000-0000-0000-000000000001"
        
        let loaded = try await RegistryService.shared.fetchUserRegistries(userId: currentUserId)
        var extendedList: [MockRegistryExtended] = []
        
        for reg in loaded {
            var ext = reg.toExtended(currentUserId: AuthSession.shared.currentUser?.id)
            // Fetch items asynchronously to set item counts accurately
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
        
        self.registries = extendedList
    }
    
    @MainActor
    func fetchRegistryDashboard(registryId: String) async throws {
        let response = try await RegistryService.shared.fetchRegistryDashboard(registryId: registryId)
        
        self.registryItems[registryId] = response.items
        
        if let idx = registries.firstIndex(where: { $0.id == registryId }) {
            registries[idx].itemsCount = response.items.count
            registries[idx].name = response.registry.theme ?? registries[idx].name
            registries[idx].date = response.registry.eventDate
            registries[idx].location = response.registry.eventLocation ?? "N/A"
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
        
        // Try to find the bundle dynamically from the backend fetched list first
        if let matchingBundle = starterBundles.first(where: { $0.bundleType == bundleType }),
           let pIds = matchingBundle.productIds, !pIds.isEmpty {
            
            let engineProducts = RecommendationEngine.shared.recommendedProducts
            for pid in pIds {
                if let found = engineProducts.first(where: { $0.id == pid }) {
                    productsToAdd.append(found)
                } else {
                    if let fetched = try? await fetchProductById(pid: pid) {
                        productsToAdd.append(fetched)
                    }
                }
            }
        }
        
        // Fallback to local catalog matches if empty
        if productsToAdd.isEmpty {
            let engineProducts = RecommendationEngine.shared.recommendedProducts
            let typeLower = bundleType.lowercased()
            
            if typeLower.contains("festive") || typeLower.contains("royal") || typeLower.contains("barware") || typeLower.contains("entertaining") || typeLower.contains("mixology") || typeLower.contains("glassware") {
                let filtered = engineProducts.filter {
                    let name = $0.name.lowercased()
                    let cat = ($0.category ?? "").lowercased()
                    return name.contains("glass") || name.contains("wine") || name.contains("appetizer") || name.contains("platter") || name.contains("board") || name.contains("cheese") || cat.contains("table") || cat.contains("bar") || cat.contains("din")
                }
                productsToAdd = Array(filtered.prefix(2))
                
                if productsToAdd.isEmpty {
                    productsToAdd = [
                        Product(id: 9670912, name: "Dorset Martini Glasses, Set of 4", price: 179.8, description: "Dorset Martini Glasses, Set of 4", imageUrl: "https://res.cloudinary.com/dl7sh9osm/image/upload/f_auto,q_auto/v1778918763/img236m.jpg", category: "bar-glasses-martini", stock: 20, tags: ["martini glasses", "cocktail glasses", "stemware"], aiReasoning: nil),
                        Product(id: 1341411, name: "Apilco Tradition Porcelain Cup & Saucer, Each", price: 34.95, description: "Apilco Tradition Porcelain Cup & Saucer, Each", imageUrl: "https://res.cloudinary.com/dl7sh9osm/image/upload/f_auto,q_auto/v1778918763/img95m.jpg", category: "cups-and-saucers", stock: 25, tags: ["cup set", "saucer", "porcelain"], aiReasoning: nil)
                    ]
                }
            } else {
                let filtered = engineProducts.filter {
                    let name = $0.name.lowercased()
                    let cat = ($0.category ?? "").lowercased()
                    return name.contains("pan") || name.contains("pot") || name.contains("chef") || name.contains("knife") || name.contains("oven") || name.contains("bake") || name.contains("mixer") || cat.contains("cook") || cat.contains("appl") || cat.contains("cut")
                }
                productsToAdd = Array(filtered.prefix(2))
                
                if productsToAdd.isEmpty {
                    productsToAdd = [
                        Product(id: 2453926, name: "Staub Enameled Cast Iron Round Dutch Oven, 7-Qt., Basil", price: 299.95, description: "Staub Enameled Cast Iron Round Dutch Oven, 7-Qt., Basil", imageUrl: "https://res.cloudinary.com/dl7sh9osm/image/upload/f_auto,q_auto/v1778918763/img83m.jpg", category: "dutch-ovens", stock: 10, tags: ["cooking pot", "dutch oven", "cast iron"], aiReasoning: nil),
                        Product(id: 181543, name: "Citron Glow Sauté & Sauce Pan", price: 180.00, description: "A vibrant yellow and black enameled pan.", imageUrl: "https://res.cloudinary.com/dl7sh9osm/image/upload/f_auto,q_auto/v1778918763/img5m.jpg", category: "Cookware", stock: 15, tags: ["sauce pan", "saute pan", "cookware"], aiReasoning: nil)
                    ]
                }
            }
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
    
    func createRegistry(name: String, type: String, date: String, location: String) async throws -> MockRegistryExtended {
        let currentUserId = AuthSession.shared.currentUser?.id ?? "00000000-0000-0000-0000-000000000001"
        
        let dto = RegistryCreationDTO(
            userId: currentUserId,
            eventType: type,
            eventDate: date,
            eventLocation: location,
            isPublic: true,
            theme: name,
            budget: 2500.0 // Default starting budget
        )
        
        let created = try await RegistryService.shared.createRegistry(dto: dto)
        let extended = created.toExtended(currentUserId: AuthSession.shared.currentUser?.id)
        
        await MainActor.run {
            self.registries.insert(extended, at: 0)
            self.registryItems[created.id] = []
        }
        
        return extended
    }
    
    func updateRegistry(id: String, name: String, date: String, location: String) {
        Task {
            do {
                _ = try await RegistryService.shared.updateRegistry(
                    registryId: id,
                    name: name,
                    date: date,
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
        if let reg = try await RegistryService.shared.joinRegistryByCode(code: code) {
            let extended = reg.toExtended(currentUserId: AuthSession.shared.currentUser?.id)
            
            await MainActor.run {
                if !self.registries.contains(where: { $0.id == reg.id }) {
                    self.registries.append(extended)
                }
            }
            return extended
        }
        return nil
    }
}

// MARK: - Helper Mapping Extension

extension Registry {
    func toExtended(currentUserId: String?) -> MockRegistryExtended {
        let bannerImage = MockRegistryService.shared.getContextAwareBannerImage(
            eventName: self.theme ?? "Celebration",
            eventType: self.eventType
        )
        
        let isOwnerVal = (currentUserId != nil && self.userId == currentUserId) || (currentUserId == nil)
        
        return MockRegistryExtended(
            id: self.id,
            code: self.shareToken ?? "GENERIC-CODE",
            name: self.theme ?? "\(self.eventType) Celebration",
            type: self.eventType,
            date: self.eventDate,
            location: self.eventLocation ?? "N/A",
            bannerImageUrl: bannerImage,
            itemsCount: 0, // Filled in dashboard fetch
            isOwner: isOwnerVal,
            eventStory: "We are excited to build our home together. Thank you for your support!",
            isAnonymousGiftingAllowed: true,
            shipDirectlyToRegistrant: true
        )
    }
}
