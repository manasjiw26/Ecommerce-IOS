import Foundation

// MARK: - Intent enum
enum ChatIntent {
    // Shopping
    case searchProducts(query: String)
    case browseCategory(category: String)
    case productQA(productId: Int?, question: String)
    case compareProducts(nameA: String, nameB: String)
    case budgetSearch(maxPrice: Double, query: String?)
    case imageSearch
    case expertCurated(persona: String)

    // Cart
    case addToCart(productName: String?, quantity: Int)
    case removeFromCart(productName: String?)
    case viewCart
    case cartOptimize
    case applyPromoCode(code: String?)
    case checkoutInitiate

    // Orders
    case orderStatus(orderId: String?)
    case orderHistory
    case reorder
    case returnRequest(orderId: String?)
    case paymentHelp

    // Recommendations
    case getRecommendations
    case moreLikeThis(productId: Int)
    case giftAdvisor(budget: Double?, occasion: String?, persona: String?)
    case completeTheSet(productId: Int)
    case occasionShopping(occasion: String)
    case recipePairing(recipe: String)
    case roomAdvisor(room: String)
    case sustainabilityFilter(query: String)
    case seasonalPicks

    // Registry
    case registryAdvisor
    case registryGapAnalysis
    case registryShare
    case guestRegistryBuy(registryId: String?)
    case createRegistry(type: String, name: String)
    case viewRegistry
    case addProductToRegistry(productName: String?, quantity: Int)
    case updateRegistryItem(productName: String?, quantity: Int?, isMostWanted: Bool?, isGroupGift: Bool?)
    case updateRegistryMetadata(date: String?, location: String?, name: String?)
    case deleteRegistryItem(productName: String?)
    case deleteRegistry

    // Watchlist / Alerts
    case watchPrice(productId: Int, threshold: Double)
    case backInStockAlert(productId: Int)
    case setReminder(productId: Int?, dateString: String)
    case flashDeals

    // Support
    case stockCheck(productId: Int?)
    case shippingEstimate(pincode: String?)
    case loyaltyPoints
    case faqQuery(topic: String)
    case piiSafetyBlock

    // Utility
    case setChatLanguage(lang: String)
    case setBudget(max: Double)
    case onboardingQuiz
    case fallback(rawText: String)
}

// MARK: - Context
struct ChatContext {
    var lastViewedProductId: Int?
    var availableCategories: [String] = []
    var hasAttachedImage: Bool = false
    var sessionBudget: Double?
    var preferredLanguage: String = "en"
}

// MARK: - Router
struct ChatIntentRouter {

    static func classify(text: String, context: ChatContext) -> ChatIntent {
        let lower = text.lowercased()

        if containsPII(lower) { return .piiSafetyBlock }

        // Cart
        if matches(lower, ["what's in my cart", "show my cart", "view cart", "cart contents"]) { return .viewCart }
        if matches(lower, ["add ", "put in cart", "add to cart"]) {
            return .addToCart(productName: extractProductName(lower, action: "add"), quantity: extractQuantity(lower))
        }
        if matches(lower, ["remove ", "delete ", "take out "]) && !matches(lower, ["return", "refund"]) {
            return .removeFromCart(productName: extractProductName(lower, action: "remove"))
        }
        if matches(lower, ["checkout", "buy now", "pay now", "place order"])              { return .checkoutInitiate }
        if matches(lower, ["reorder", "order again", "buy again"])                        { return .reorder }
        if matches(lower, ["cheaper", "alternative", "swap", "optimize cart"])            { return .cartOptimize }

        // Orders
        if matches(lower, ["where is my order", "track", "order status", "when will", "my order "]) {
            return .orderStatus(orderId: extractOrderId(lower))
        }
        if matches(lower, ["past orders", "order history", "previous orders", "my orders"]) { return .orderHistory }
        if matches(lower, ["return", "refund", "send back", "cancel"]) { return .returnRequest(orderId: extractOrderId(lower)) }
        if matches(lower, ["payment failed", "payment issue", "couldn't pay"]) { return .paymentHelp }

        // Gift / Occasion
        if matches(lower, ["gift", "present", "birthday", "anniversary", "wedding gift"]) {
            return .giftAdvisor(budget: extractPrice(lower), occasion: nil, persona: extractPersona(lower))
        }
        if matches(lower, ["thanksgiving", "dinner party", "christmas", "hosting", "holiday"]) {
            return .occasionShopping(occasion: lower)
        }
        if matches(lower, ["recipe", "make ", "cook ", "bake "]) { return .recipePairing(recipe: lower) }
        if matches(lower, ["new kitchen", "living room", "equip my", "set up my", "remodel", "renovating"])  { return .roomAdvisor(room: lower) }
        if matches(lower, ["expert", "chef", "designer", "bartender", "professional"]) {
            return .expertCurated(persona: extractPersona(lower) ?? "expert")
        }

        // Recommendations
        if matches(lower, ["recommend", "suggest", "what should i", "picked for me", "personalise"]) {
            return .getRecommendations
        }
        if matches(lower, ["similar", "like this", "more like"]) {
            if let id = context.lastViewedProductId { return .moreLikeThis(productId: id) }
            return .fallback(rawText: text)
        }
        if matches(lower, ["complete the set", "goes with", "goes well with", "goes well", "pairs with", "what else"]) {
            if let id = context.lastViewedProductId { return .completeTheSet(productId: id) }
            return .fallback(rawText: text)
        }
        if matches(lower, ["trending", "popular", "best seller"])                          { return .seasonalPicks }
        // Product QA
        if matches(lower, ["is it", "does it", "how much", "how big", "warranty", "material", "made of", "dishwasher", "microwave", "oven safe"]) {
            return .productQA(productId: context.lastViewedProductId, question: text)
        }
        if matches(lower, ["eco", "sustainable", "non-toxic", "bpa", "organic", "environment"])  { return .sustainabilityFilter(query: lower) }

        // Registry CRUD operations
        if matches(lower, ["delete my registry", "remove my registry", "destroy my registry", "cancel my registry"]) {
            return .deleteRegistry
        }
        if matches(lower, ["delete ", "remove ", "take out of ", "take out "]) && matches(lower, ["registry"]) {
            let prodName = extractRegistryProductName(lower)
            return .deleteRegistryItem(productName: prodName)
        }
        if matches(lower, ["create ", "start ", "make ", "new "]) && matches(lower, ["registry"]) {
            let type = lower.contains("wedding") ? "wedding" : (lower.contains("baby") ? "baby shower" : (lower.contains("anniversary") ? "anniversary" : "celebration"))
            let name = extractRegistryName(lower) ?? "My \(type.capitalized) Registry"
            return .createRegistry(type: type, name: name)
        }
        if matches(lower, ["add ", "put "]) && matches(lower, ["registry"]) {
            let prodName = extractRegistryProductName(lower)
            return .addProductToRegistry(productName: prodName, quantity: extractQuantity(lower))
        }
        if matches(lower, ["update registry date", "change registry date", "update registry location", "rename registry"]) {
            let date = extractDateString(lower)
            let loc = extractLocationString(lower)
            let name = extractRegistryName(lower)
            return .updateRegistryMetadata(date: date, location: loc, name: name)
        }
        if matches(lower, ["change ", "update ", "set ", "make "]) && matches(lower, ["registry"]) {
            let prodName = extractRegistryProductName(lower)
            let qty = lower.contains("quantity") || lower.contains("qty") ? extractQuantity(lower) : nil
            let mostWanted = lower.contains("most wanted") ? true : (lower.contains("not most wanted") ? false : nil)
            let groupGift = lower.contains("group gift") || lower.contains("group gifting") ? true : nil
            return .updateRegistryItem(productName: prodName, quantity: qty, isMostWanted: mostWanted, isGroupGift: groupGift)
        }
        if matches(lower, ["view my registry", "show my registry", "what's in my registry", "view registry", "show registry", "get my registry", "display registry"]) {
            return .viewRegistry
        }
        if matches(lower, ["my registry", "wedding registry", "baby shower registry"]) { return .registryAdvisor }
        if matches(lower, ["missing from registry", "registry gap", "what should i add"])                 { return .registryGapAnalysis }
        if matches(lower, ["share my registry", "send registry link"])                                     { return .registryShare }

        // Watchlist
        if matches(lower, ["alert me", "notify me when", "price drops", "let me know when"]) {
            if matches(lower, ["stock", "available"]) {
                return .backInStockAlert(productId: context.lastViewedProductId ?? 0)
            }
            return .watchPrice(productId: context.lastViewedProductId ?? 0, threshold: extractPrice(lower) ?? 0)
        }
        if matches(lower, ["remind me", "reminder"]) { return .setReminder(productId: context.lastViewedProductId, dateString: lower) }
        if matches(lower, ["deals", "discount", "sale", "flash", "offer"])    { return .flashDeals }
        if matches(lower, ["promo", "coupon", "code", "voucher"])             { return .applyPromoCode(code: extractPromoCode(lower)) }

        // Account
        if matches(lower, ["points", "loyalty", "rewards"])                               { return .loyaltyPoints }
        if matches(lower, ["delivery", "shipping", "how long", "when will it arrive"])    { return .shippingEstimate(pincode: extractPincode(lower)) }
        if matches(lower, ["in stock", "available", "stock check"])                       { return .stockCheck(productId: context.lastViewedProductId) }
        if matches(lower, ["return policy", "refund policy", "how do i", "help", "faq"]) { return .faqQuery(topic: lower) }

        // Budget
        if let budget = extractPrice(lower), matches(lower, ["budget", "under", "less than", "below", "only have"]) {
            return .budgetSearch(maxPrice: budget, query: nil)
        }

        // Language
        if matches(lower, ["hindi", "हिंदी", "hinglish"]) { return .setChatLanguage(lang: "hi") }

        // Category browse
        for category in context.availableCategories where lower.contains(category.lowercased()) {
            return .browseCategory(category: category)
        }

        // Generic Product Search (Catch-all for shopping)
        if matches(lower, ["find", "search", "looking for", "show me", "do you have", "i want to buy", "get me", "plates", "bowls", "cups", "glasses", "pans", "pots", "skillet", "kitchenware", "cookware", "tableware", "dinnerware"]) {
            return .searchProducts(query: text)
        }

        // Image attached
        if context.hasAttachedImage { return .imageSearch }

        return .fallback(rawText: text)
    }

    // MARK: - Helpers
    private static func matches(_ text: String, _ patterns: [String]) -> Bool {
        patterns.contains { text.contains($0) }
    }

    private static func extractPrice(_ text: String) -> Double? {
        let pattern = #"[\$₹]?\s*(\d+(?:\.\d{2})?)"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        let numStr = String(text[range]).filter { $0.isNumber || $0 == "." }
        return Double(numStr)
    }

    private static func extractOrderId(_ text: String) -> String? {
        guard let range = text.range(of: #"ORD-\d{5}"#, options: .regularExpression) else { return nil }
        return String(text[range])
    }

    private static func extractPersona(_ text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("mom") || lower.contains("mother") { return "mom" }
        if lower.contains("dad") || lower.contains("father") { return "dad" }
        if lower.contains("chef")                            { return "chef" }
        if lower.contains("designer")                        { return "designer" }
        if lower.contains("bartender")                       { return "bartender" }
        if lower.contains("professional")                    { return "professional" }
        if lower.contains("partner") || lower.contains("wife") || lower.contains("husband") { return "partner" }
        if lower.contains("sister") || lower.contains("brother") { return "sibling" }
        return nil
    }

    private static func extractPincode(_ text: String) -> String? {
        guard let range = text.range(of: #"\b\d{6}\b"#, options: .regularExpression) else { return nil }
        return String(text[range])
    }

    private static func extractPromoCode(_ text: String) -> String? {
        guard let range = text.range(of: #"\b[A-Z]{2,}\d{0,4}\b"#, options: .regularExpression) else { return nil }
        return String(text[range])
    }

    private static func containsPII(_ text: String) -> Bool {
        text.range(of: #"\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b"#, options: .regularExpression) != nil
    }

    private static func extractQuantity(_ text: String) -> Int {
        let textLower = text.lowercased()
        if textLower.contains("two") { return 2 }
        if textLower.contains("three") { return 3 }
        if textLower.contains("four") { return 4 }
        if textLower.contains("five") { return 5 }
        if let match = text.range(of: #"\b\d+\b"#, options: .regularExpression), let num = Int(text[match]) {
            return num
        }
        return 1
    }

    private static func extractProductName(_ text: String, action: String) -> String? {
        // Strip common fluff around the product name
        var clean = text.lowercased()
        let fluff = [
            "add ", "remove ", "delete ", "take out ", "put in my cart", "put in cart", "add to cart", 
            "to my cart", "from my cart", "in my cart", "please", "i want to", "can you",
            "one ", "two ", "three ", "four ", "five ", "a ", "an ", "the "
        ]
        
        // Also strip numbers
        clean = clean.replacingOccurrences(of: #"\b\d+\b"#, with: "", options: .regularExpression)
        
        for word in fluff {
            clean = clean.replacingOccurrences(of: word, with: "")
        }
        
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.trimmingCharacters(in: CharacterSet(charactersIn: ".?!"))
        
        // If they said "skillets", remove the trailing 's' to match "skillet"
        if clean.hasSuffix("s") && !clean.hasSuffix("ss") {
            clean = String(clean.dropLast())
        }
        
        return clean.isEmpty ? nil : clean
    }

    private static func extractRegistryProductName(_ text: String) -> String? {
        var clean = text.lowercased()
        
        let prefixes = [
            "add ", "remove ", "delete ", "take out of ", "take out ", "change ", "update ", "set ", "make ",
            "to my registry", "from my registry", "in my registry", "to registry", "from registry",
            "quantity of ", "qty of ", "most wanted ", "group gift "
        ]
        
        for p in prefixes {
            clean = clean.replacingOccurrences(of: p, with: "")
        }
        
        clean = clean.replacingOccurrences(of: #"\b\d+\b"#, with: "", options: .regularExpression)
        
        let helpers = ["please", "i want to", "can you", "one", "two", "three", "four", "five", "a", "an", "the", "in", "to", "from", "on"]
        for h in helpers {
            clean = clean.replacingOccurrences(of: #"\b\(h)\b"#, with: "", options: .regularExpression)
        }
        
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.trimmingCharacters(in: CharacterSet(charactersIn: ".?!"))
        
        if clean.hasSuffix("s") && !clean.hasSuffix("ss") {
            clean = String(clean.dropLast())
        }
        
        return clean.isEmpty ? nil : clean
    }

    private static func extractRegistryName(_ text: String) -> String? {
        let lower = text.lowercased()
        if let range = text.range(of: "\"[^\"]+\"", options: .regularExpression) {
            return String(text[range]).replacingOccurrences(of: "\"", with: "")
        }
        if let range = lower.range(of: "called ") {
            return String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = lower.range(of: "named ") {
            return String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func extractDateString(_ text: String) -> String? {
        let pattern = #"\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]* \d{1,2},? \d{4}\b|\b\d{4}-\d{2}-\d{2}\b"#
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return String(text[range])
    }

    private static func extractLocationString(_ text: String) -> String? {
        let lower = text.lowercased()
        if let range = lower.range(of: "in ") {
            var rest = String(text[range.upperBound...])
            if let onRange = rest.lowercased().range(of: " on ") {
                rest = String(rest[..<onRange.lowerBound])
            }
            return rest.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = lower.range(of: "at ") {
            var rest = String(text[range.upperBound...])
            if let onRange = rest.lowercased().range(of: " on ") {
                rest = String(rest[..<onRange.lowerBound])
            }
            return rest.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
