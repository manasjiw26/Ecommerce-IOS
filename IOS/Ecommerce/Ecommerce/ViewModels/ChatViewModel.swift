import Foundation
import SwiftUI
import UIKit
import UserNotifications
import Combine
import Combine

@MainActor
class ChatViewModel: ObservableObject {

    // MARK: - Published state
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var selectedImage: UIImage? = nil
    @Published var showImagePicker: Bool = false
    @Published var sessionBudget: Double? = nil
    @Published var preferredCurrency: String = "USD"

    // MARK: - Internal state
    internal var context = ChatContext()
    private let baseURL = APIService.baseURL
    // Hardcode proxy endpoint relative to baseURL instead of absolute, easier for dev
    private var aiBaseURL: String { "\(baseURL)/chat" }
    private var conversationHistory: [[String: String]] = []

    // Injected managers
    var cartManager: CartManager?
    var productViewModel: ProductViewModel?

    // MARK: - Init
    init() {
        loadChatHistory()
        loadUserPreferences()
        sendWelcomeMessage()
    }

    // Load available categories when products are available
    func updateContext() {
        if let products = productViewModel?.products {
            context.availableCategories = Array(Set(products.compactMap { $0.category }))
        }
    }

    // MARK: - Send message (main entry point)
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || selectedImage != nil else { return }

        // Add user message
        let userMsg = ChatMessage(role: .user, text: text)
        append(userMsg)
        inputText = ""

        // Add typing indicator
        let typingMsg = ChatMessage(role: .assistant, text: "", isLoading: true)
        append(typingMsg)
        let loadingIndex = messages.count - 1

        isLoading = true

        updateContext()

        Task {
            do {
                try await route(intent: ChatIntentRouter.classify(text: text, context: context),
                               rawText: text,
                               loadingIndex: loadingIndex)
            } catch {
                replaceLoading(at: loadingIndex, with: ChatMessage(
                    role: .assistant,
                    text: "Something went wrong reaching the server. Try again in a moment."
                ))
                print("Chat error: \(error)")
            }
            isLoading = false
            saveChatHistory()
        }
    }

    // MARK: - Intent router
    private func route(intent: ChatIntent, rawText: String, loadingIndex: Int) async throws {
        switch intent {

        // ── SEARCH & BROWSE ──────────────────────────────────────────────
        case .searchProducts(let query):
            let products = try await searchProducts(query: query)
            let reply = products.isEmpty
                ? "I couldn't find anything for \"\(query)\" — try different keywords."
                : "Here's what I found for \"\(query)\":"
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant, text: reply,
                attachments: [.products(products), .quickReplies(["Show recommendations", "Different category"])]
            ))

        case .browseCategory(let category):
            let products = productViewModel?.products.filter { $0.category?.lowercased() == category.lowercased() } ?? []
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: "Here's everything in \(category.capitalized):",
                attachments: [.products(products)]
            ))

        case .budgetSearch(let max, let query):
            sessionBudget = max
            context.sessionBudget = max
            var products = productViewModel?.products.filter { $0.price <= max } ?? []
            if let q = query { products = products.filter { $0.name.localizedCaseInsensitiveContains(q) } }
            let formatted = formatPrice(max)
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: products.isEmpty ? "No items found under \(formatted)." : "Showing everything under \(formatted):",
                attachments: [.products(products), .quickReplies(["Filter by category", "Clear budget"])]
            ))

        case .productQA(let productId, let question):
            let product = productId != nil
                ? productViewModel?.products.first(where: { $0.id == productId })
                : productViewModel?.products.first(where: { context.lastViewedProductId == $0.id })
            let answer = try await answerProductQuestion(product: product, question: question)
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: answer))

        case .compareProducts(let nameA, let nameB):
            let a = productViewModel?.products.first(where: { $0.name.localizedCaseInsensitiveContains(nameA) })
            let b = productViewModel?.products.first(where: { $0.name.localizedCaseInsensitiveContains(nameB) })
            guard let a, let b else {
                replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: "I couldn't find both products to compare — try using their exact names."))
                return
            }
            let comparison = buildComparison(a, b)
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: comparison, attachments: [.priceComparison(a, b)]))

        case .imageSearch:
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: "Image search is not fully implemented yet, but I can recommend items instead!", attachments: [.quickReplies(["Show recommendations"])]))
            selectedImage = nil

        case .sustainabilityFilter(let query):
            let keywords = ["non-toxic", "bpa-free", "eco", "organic", "stainless", "ceramic", "bamboo", "recycled"]
            let products = productViewModel?.products.filter { p in
                keywords.contains(where: { p.description?.lowercased().contains($0) == true || p.name.lowercased().contains($0) })
            } ?? []
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: products.isEmpty ? "I couldn't find eco-friendly matches — try a broader search." : "Here are sustainable options:",
                attachments: [.products(products)]
            ))

        // ── RECOMMENDATIONS ──────────────────────────────────────────────
        case .getRecommendations:
            let curated = try await fetchRecommendedProductIds(persona: nil, budget: sessionBudget, occasion: nil)
            if curated.isEmpty {
                replaceLoading(at: loadingIndex, with: ChatMessage(
                    role: .assistant,
                    text: "I don't have enough history to make a specific pick yet. Try exploring the Shop tab or telling me what you're looking for!",
                    attachments: [.quickReplies(["Help me find a gift", "Trending picks"])]
                ))
            } else {
                replaceLoading(at: loadingIndex, with: ChatMessage(
                    role: .assistant,
                    text: "Here's what I picked for you based on your browsing:",
                    attachments: [.products(curated), .quickReplies(["Different style", "Under $50"])]
                ))
            }

        case .moreLikeThis(let productId):
            RecommendationEngine.shared.logEvent(productId: productId, eventType: "view")
            await RecommendationEngine.shared.fetchRecommendations()
            let products = RecommendationEngine.shared.recommendedProducts.filter { $0.id != productId }
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant, text: "Here are similar picks:",
                attachments: [.products(Array(products.prefix(6)))]
            ))

        case .giftAdvisor(let budget, let occasion, let persona):
            let system = "You are a gift advisor. Suggest 3-4 specific product categories that make great gifts. You MUST ONLY choose from this exact list: \(allCategories()). Return ONLY a comma-separated list. No other text."
            let user = "Occasion: \(occasion ?? "gift"). Recipient: \(persona ?? "someone")."
            let answer = try await callLLM(system: system, user: user)
            let keywords = parseKeywords(from: answer)
            
            var products: [Product] = []
            for keyword in keywords {
                if let p = productViewModel?.products.first(where: { $0.name.localizedCaseInsensitiveContains(keyword) || $0.category?.localizedCaseInsensitiveContains(keyword) == true }) {
                    if !products.contains(where: { $0.id == p.id }) {
                        products.append(p)
                    }
                }
            }
            if let max = budget { products = products.filter { $0.price <= max } }
            
            let personaStr = persona.map { "for \($0)" } ?? ""
            let budgetStr = budget.map { " under \(formatPrice($0))" } ?? ""
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: products.isEmpty ? "I couldn't find matches for those criteria." : "Great gift ideas \(personaStr)\(budgetStr):",
                attachments: [.products(products)]
            ))

        case .completeTheSet(let productId):
            let baseProduct = productViewModel?.products.first { $0.id == productId }
            let system = "Given a product name and category, suggest 3 complementary item categories to complete the set. You MUST ONLY choose from this exact list: \(allCategories()). Return ONLY a comma-separated list. No other text."
            let answer = try await callLLM(system: system, user: "Product: \(baseProduct?.name ?? "unknown"). Category: \(baseProduct?.category ?? "unknown").")
            let keywords = parseKeywords(from: answer)
            
            var products: [Product] = []
            for keyword in keywords {
                if let p = productViewModel?.products.first(where: { ($0.category?.localizedCaseInsensitiveContains(keyword) == true || $0.name.localizedCaseInsensitiveContains(keyword)) && $0.id != productId }) {
                    if !products.contains(where: { $0.id == p.id }) {
                        products.append(p)
                    }
                }
            }
            
            let text = products.isEmpty ? "I couldn't find any perfect complementary items for this right now." : "Complete the set — frequently paired with \(baseProduct?.name ?? "this item"):"
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: text,
                attachments: products.isEmpty ? [] : [.products(products)]
            ))

        case .occasionShopping(let occasion):
            let categories = occasionToCategories(occasion)
            var curated: [Product] = []
            for cat in categories {
                if let top = productViewModel?.products.first(where: { $0.category?.lowercased() == cat }) {
                    curated.append(top)
                }
            }
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: "Here's a curated kit for the occasion:",
                attachments: [.products(curated)]
            ))

        case .recipePairing(let recipe):
            let answer = try await callLLM(system: recipeSystemPrompt(), user: "What cookware and tools do I need to make: \(recipe)?")
            let tools = parseKeywords(from: answer)
            var matched: [Product] = []
            for tool in tools {
                if let p = productViewModel?.products.first(where: { $0.category?.localizedCaseInsensitiveContains(tool) == true || $0.name.localizedCaseInsensitiveContains(tool) }) {
                    if !matched.contains(where: { $0.id == p.id }) {
                        matched.append(p)
                    }
                }
            }
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: "To make \(recipe.prefix(40)), you might need:",
                attachments: [.products(matched)]
            ))

        case .seasonalPicks:
            let month = Calendar.current.component(.month, from: Date())
            let seasonalCategory = seasonalCategory(for: month)
            let products = productViewModel?.products.filter { $0.category == seasonalCategory } ?? []
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: "Trending picks for this time of year:",
                attachments: [.products(Array(products.prefix(6)))]
            ))

        case .expertCurated(let persona):
            let products = try await loadExpertCurated(persona: persona)
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: "A professional \(persona) would pick these:",
                attachments: [.products(products)]
            ))

        case .roomAdvisor:
            let answer = try await callLLM(
                system: "You are a kitchen and home expert. The user wants to equip a space. Ask 2 short clarifying questions about their style and budget, then suggest product categories from this list: \(allCategories()). Be conversational. CRITICAL: Maximum 20 words total.",
                user: rawText
            )
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: answer,
                attachments: [.quickReplies(["Professional", "Beginner", "Under $200"])]
            ))

        // ── CART ──────────────────────────────────────────────────────────
        case .viewCart:
            let items = cartManager?.items ?? []
            if items.isEmpty {
                replaceLoading(at: loadingIndex, with: ChatMessage(
                    role: .assistant, text: "Your cart is empty. Want me to find something?",
                    attachments: [.quickReplies(["Show recommendations", "Browse cookware", "Search products"])]
                ))
            } else {
                let total = cartManager?.total ?? 0
                let summary = items.map { "· \($0.product.name) ×\($0.quantity) — \(formatPrice($0.product.price))" }.joined(separator: "\n")
                replaceLoading(at: loadingIndex, with: ChatMessage(
                    role: .assistant,
                    text: "Your cart (\(items.count) items):\n\(summary)\n\nTotal: \(formatPrice(total))",
                    attachments: [.cartSummary, .quickReplies(["Checkout", "Optimize cart"])]
                ))
            }

        case .addToCart(let productName, let quantity):
            if let name = productName, let product = findProduct(by: name) {
                for _ in 0..<quantity { cartManager?.addToCart(product: product) }
                RecommendationEngine.shared.logEvent(productId: product.id, eventType: "add_to_cart")
                let priceStr = formatPrice(product.price)
                replaceLoading(at: loadingIndex, with: ChatMessage(
                    role: .assistant,
                    text: "Added \(quantity > 1 ? "\(quantity)× " : "")\(product.name) (\(priceStr)) to your cart.",
                    attachments: [.quickReplies(["View cart", "Keep shopping", "Checkout now"])]
                ))
            } else {
                replaceLoading(at: loadingIndex, with: ChatMessage(
                    role: .assistant, text: "Which product would you like to add? I can search for it.",
                    attachments: [.quickReplies(["Search products", "Show recommendations"])]
                ))
            }

        case .removeFromCart(let productName):
            if let name = productName, let product = findProduct(by: name),
               let index = cartManager?.items.firstIndex(where: { $0.product.id == product.id }) {
                if let item = cartManager?.items[index] {
                    cartManager?.removeFromCart(product: item.product)
                    replaceLoading(at: loadingIndex, with: ChatMessage(
                        role: .assistant, 
                        text: "Removed \(item.product.name) from your cart.", 
                        attachments: [.cartSummary]
                    ))
                }
            } else {
                replaceLoading(at: loadingIndex, with: ChatMessage(
                    role: .assistant, 
                    text: "I couldn't find that item in your cart."
                ))
            }

        case .cartOptimize:
            let items = cartManager?.items ?? []
            var swaps: [(CartItem, Product)] = []
            for item in items {
                if let cheaper = productViewModel?.products
                    .filter({ $0.category == item.product.category && $0.price < item.product.price && $0.id != item.product.id })
                    .sorted(by: { $0.price < $1.price })
                    .first {
                    swaps.append((item, cheaper))
                }
            }
            if swaps.isEmpty {
                replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: "Your cart already has great value — no cheaper alternatives found in the same categories."))
            } else {
                let desc = swaps.map {
                    "Swap \($0.0.product.name) (\(formatPrice($0.0.product.price))) → \($0.1.name) (\(formatPrice($0.1.price))) · save \(formatPrice($0.0.product.price - $0.1.price))"
                }.joined(separator: "\n")
                let altProducts = swaps.map { $0.1 }
                replaceLoading(at: loadingIndex, with: ChatMessage(
                    role: .assistant, text: "I found cheaper alternatives:\n\(desc)",
                    attachments: [.products(altProducts)]
                ))
            }

        case .checkoutInitiate:
            let items = cartManager?.items ?? []
            guard !items.isEmpty else {
                replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: "Your cart is empty — add some items first."))
                return
            }
            let total = cartManager?.total ?? 0
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: "Ready to checkout! Your total is \(formatPrice(total)). Tap the button in the Cart tab to complete your purchase.",
                attachments: [.quickReplies(["Apply promo code", "View cart first"])]
            ))

        case .applyPromoCode(let code):
            if let code {
                let result = try await applyPromo(code: code)
                replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: result))
            } else {
                let promos = try await fetchActivePromos()
                replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: promos))
            }

        // ── ORDERS ────────────────────────────────────────────────────────
        case .orderStatus(let orderId):
            if OrderManager.shared.orders.isEmpty { await OrderManager.shared.fetchOrders() }
            let orders = OrderManager.shared.orders
            let order = orderId != nil
                ? orders.first { $0.id == orderId }
                : orders.first
            if let order {
                replaceLoading(at: loadingIndex, with: ChatMessage(
                    role: .assistant,
                    text: "Your latest order status:",
                    attachments: [.order(order), .quickReplies(["Return this order", "Reorder", "More orders"])]
                ))
            } else {
                replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: "No orders found. Place your first order from the Cart tab!"))
            }

        case .orderHistory:
            if OrderManager.shared.orders.isEmpty { await OrderManager.shared.fetchOrders() }
            let orders = OrderManager.shared.orders
            if orders.isEmpty {
                replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: "You haven't placed any orders yet."))
            } else {
                let summary = orders.prefix(5).map {
                    "· \($0.itemsSummary.prefix(40)) — \(formatPrice($0.total)) · \($0.status)"
                }.joined(separator: "\n")
                replaceLoading(at: loadingIndex, with: ChatMessage(
                    role: .assistant, text: "Your recent orders:\n\(summary)",
                    attachments: [.quickReplies(["Track latest", "Reorder last purchase", "Return an order"])]
                ))
            }

        case .reorder:
            guard let last = OrderManager.shared.orders.first else {
                replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: "No previous orders found."))
                return
            }
            let names = last.itemsSummary.components(separatedBy: ", ").map {
                $0.components(separatedBy: " x").first ?? $0
            }
            var added: [String] = []
            for name in names {
                if let product = productViewModel?.products.first(where: { $0.name.localizedCaseInsensitiveContains(name.trimmingCharacters(in: .whitespaces)) }) {
                    cartManager?.addToCart(product: product)
                    added.append(product.name)
                }
            }
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: added.isEmpty ? "Couldn't match your previous items to current catalog." : "Re-added to your cart:\n" + added.map { "· \($0)" }.joined(separator: "\n"),
                attachments: [.quickReplies(["Go to checkout", "View cart"])]
            ))

        case .returnRequest(let orderId):
            if OrderManager.shared.orders.isEmpty { await OrderManager.shared.fetchOrders() }
            let order = orderId != nil
                ? OrderManager.shared.orders.first { $0.id == orderId }
                : OrderManager.shared.orders.first
            guard let order else {
                replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: "I couldn't find that order. Check the Orders tab."))
                return
            }
            let result = try await submitReturn(orderId: order.id, paymentId: order.paymentId)
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: result))

        case .paymentHelp:
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: "Sorry to hear your payment didn't go through. A few things to try:\n· Make sure your card has international/online transaction enabled\n· Check that the CVV and billing address match\n· Try a different payment method in Razorpay\n\nWant me to restart the checkout flow?",
                attachments: [.quickReplies(["Retry checkout", "Contact support"])]
            ))

        // ── WATCHLIST / ALERTS ────────────────────────────────────────────
        case .watchPrice(let productId, let threshold):
            let result = try await registerPriceWatch(productId: productId, threshold: threshold)
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: result))

        case .backInStockAlert(let productId):
            let result = try await registerStockAlert(productId: productId)
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: result))

        case .setReminder(let productId, let dateString):
            scheduleLocalReminder(productId: productId, dateString: dateString)
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: "Reminder set! I'll notify you when the time comes."))

        case .flashDeals:
            let deals = try await fetchFlashDeals()
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant, text: "Here are today's deals:",
                attachments: [.products(deals)]
            ))

        // ── REGISTRY ──────────────────────────────────────────────────────
        case .registryAdvisor:
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: "I'll help you build the perfect registry! What's the occasion?",
                attachments: [.quickReplies(["Wedding", "Baby shower", "Housewarming", "Birthday"])]
            ))

        case .registryGapAnalysis:
            let advice = try await callLLM(
                system: "You help people optimize their gift registries. Given a list of items in their registry, identify what categories are missing for a complete home. Keep it to exactly 3 ultra-short bullet points. Under 20 words total.",
                user: "My registry items are in these categories. What am I missing for a well-equipped kitchen and dining room?"
            )
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: advice))

        case .registryShare:
            let userId = AuthSession.shared.currentUser?.id ?? ""
            let link = "\(baseURL)/registry/\(userId)"
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: "Here's your registry link — tap to share:\n\(link)",
                attachments: [.quickReplies(["Copy link"])]
            ))

        case .guestRegistryBuy:
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant,
                text: "Sure! Enter the registry owner's name or registry ID and I'll pull it up."
            ))

        // ── SUPPORT ───────────────────────────────────────────────────────
        case .stockCheck(let productId):
            let pid = productId ?? context.lastViewedProductId
            guard let pid else {
                replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: "Which product would you like to check stock for?"))
                return
            }
            if let product = productViewModel?.products.first(where: { $0.id == pid }) {
                let stock = product.stock ?? 0
                let msg = stock > 0 ? "\(product.name) is in stock (\(stock) remaining)." : "\(product.name) is currently out of stock."
                replaceLoading(at: loadingIndex, with: ChatMessage(
                    role: .assistant, text: msg,
                    attachments: stock == 0 ? [.quickReplies(["Notify me when back", "Find similar"])] : []
                ))
            } else {
                replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: "Product not found."))
            }

        case .shippingEstimate(let pincode):
            let estimate = pincode != nil
                ? "Delivery to pincode \(pincode!) usually takes 3–5 business days with standard shipping."
                : "Enter your pincode and I'll give you an estimate."
            replaceLoading(at: loadingIndex, with: ChatMessage(
                role: .assistant, text: estimate,
                attachments: pincode == nil ? [.quickReplies(["400001 (Mumbai)", "110001 (Delhi)", "560001 (Bengaluru)"])] : []
            ))

        case .loyaltyPoints:
            let points = try await fetchLoyaltyPoints()
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: points))

        case .faqQuery(let topic):
            let answer = faqAnswer(for: topic)
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: answer,
                attachments: [.quickReplies(["Return policy", "Shipping info", "Payment methods", "Contact support"])]
            ))

        // ── UTILITY ────────────────────────────────────────────────────────
        case .setChatLanguage(let lang):
            context.preferredLanguage = lang
            UserDefaults.standard.set(lang, forKey: "chatLanguage")
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: lang == "hi" ? "बिल्कुल! अब मैं हिंदी में जवाब दूंगा।" : "Switching to English."))

        case .setBudget(let max):
            sessionBudget = max
            context.sessionBudget = max
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: "Budget set to \(formatPrice(max)). I'll only show products within this range."))

        case .piiSafetyBlock:
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: "For your security, please never share card numbers or passwords in chat. Payments are handled securely through Razorpay."))

        case .fallback(let rawText):
            let systemPrompt = buildSystemPrompt()
            let reply = try await callLLM(system: systemPrompt, user: rawText)
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: reply,
                attachments: suggestQuickReplies(for: rawText)
            ))
            
        case .onboardingQuiz:
            replaceLoading(at: loadingIndex, with: ChatMessage(role: .assistant, text: "Let's find your style! Do you prefer modern minimalism or classic charm?"))
        }
    }

    // MARK: - LLM caller
    func callLLM(system: String, user: String) async throws -> String {
        guard let url = URL(string: aiBaseURL) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        conversationHistory.append(["role": "user", "content": user])

        let body: [String: Any] = [
            "system": system,
            "messages": conversationHistory,
            "max_tokens": 800
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONDecoder().decode([String: AnyValue].self, from: data)
        var reply = "I'm having trouble thinking right now."
        
        // Handle Gemini API response structure typically wrapped by proxy
        if let contentArray = json["content"]?.arrayValue,
           let firstObj = contentArray.first?.dictionaryValue,
           let text = firstObj["text"]?.stringValue {
            reply = text
        } else if let errorMsg = json["error"]?.stringValue {
            reply = "Error: \(errorMsg)"
        }

        conversationHistory.append(["role": "assistant", "content": reply])
        return reply
    }

    // MARK: - System prompt builder
    private func buildSystemPrompt() -> String {
        let cartSummary = cartManager?.items.map { "\($0.product.name) x\($0.quantity)" }.joined(separator: ", ") ?? "empty"
        let userName = AuthSession.shared.currentUser?.name ?? "there"
        let language = context.preferredLanguage == "hi" ? "Respond in Hindi." : "Respond in English."
        let budget = sessionBudget.map { " The user's budget is \(formatPrice($0))." } ?? ""

        return """
        You are a shopping assistant for Hearth & Table. Be warm and friendly but EXTREMELY concise.
        NEVER introduce yourself as an AI or say "As an AI". You are simply the store's assistant.
        CRITICAL: Your responses MUST be 1 or 2 short sentences maximum. Under 20 words.
        The user's name is \(userName). Their cart currently has: \(cartSummary).\(budget)
        Only state product facts (price, stock) that come from real API data.
        If asked something outside shopping, pivot back to home goods.
        Never repeat credit card numbers or payment details.
        \(language)
        """
    }

    // MARK: - Network helpers
    private func searchProducts(query: String) async throws -> [Product] {
        RecommendationEngine.shared.searchProducts(query: query)
        try await Task.sleep(nanoseconds: 2_000_000_000) // wait for callback results
        return RecommendationEngine.shared.searchResults
    }

    private func fetchRecommendedProductIds(persona: String?, budget: Double?, occasion: String?) async throws -> [Product] {
        await RecommendationEngine.shared.fetchRecommendations()
        var products = RecommendationEngine.shared.recommendedProducts
        if let max = budget { products = products.filter { $0.price <= max } }
        return Array(products.prefix(6))
    }

    private func answerProductQuestion(product: Product?, question: String) async throws -> String {
        guard let p = product else {
            return "I need you to open a specific product page first so I can look up those details for you!"
        }
        let context = "Product: \(p.name). Description: \(p.description ?? "N/A"). Category: \(p.category ?? "N/A"). Price: \(formatPrice(p.price)). Stock: \(p.stock ?? 0)."
        return try await callLLM(
            system: "You answer questions about specific products using only the provided product data. If the answer isn't in the data, say 'that information isn't available.' CRITICAL: Your responses MUST be under 20 words total.",
            user: "\(context)\n\nQuestion: \(question)"
        )
    }

    private func submitReturn(orderId: String, paymentId: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/returns") else { return "Return service unavailable." }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["order_id": orderId, "payment_id": paymentId, "reason": "Customer request"])
        let (_, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 500
        return code == 200 ? "Return request submitted for order \(orderId)." : "Couldn't process the return."
    }

    private func registerPriceWatch(productId: Int, threshold: Double) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/watchlist") else { return "Service unavailable." }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "device_id": RecommendationEngine.shared.deviceId,
            "product_id": productId,
            "threshold_price": threshold
        ])
        let (_, _) = try await URLSession.shared.data(for: req)
        return "Got it — I'll notify you when the price drops to \(formatPrice(threshold))."
    }

    private func registerStockAlert(productId: Int) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/watchlist") else { return "Service unavailable." }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "device_id": RecommendationEngine.shared.deviceId,
            "product_id": productId,
            "type": "stock_alert"
        ])
        let (_, _) = try await URLSession.shared.data(for: req)
        return "Done — you'll get a notification the moment it's back in stock."
    }

    private func scheduleLocalReminder(productId: Int?, dateString: String) {
        let content = UNMutableNotificationContent()
        content.title = "Hearth & Table reminder"
        content.body = "You asked me to remind you about an item."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 86400, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func fetchFlashDeals() async throws -> [Product] {
        guard let url = URL(string: "\(baseURL)/chat/deals/active") else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        return (try? JSONDecoder().decode([Product].self, from: data)) ?? []
    }

    private func fetchLoyaltyPoints() async throws -> String {
        guard let userId = AuthSession.shared.currentUser?.id,
              let url = URL(string: "\(baseURL)/chat/users/\(userId)/points") else {
            return "Log in to see your loyalty points."
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        if let json = try? JSONDecoder().decode([String: Int].self, from: data), let pts = json["points"] {
            return "You have \(pts) loyalty points. Keep shopping to earn more!"
        }
        return "Couldn't fetch points right now."
    }

    private func applyPromo(code: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/promotions/apply") else { return "Promo service unavailable." }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["code": code])
        let (data, response) = try await URLSession.shared.data(for: req)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        if statusCode == 200, let json = try? JSONDecoder().decode([String: AnyValue].self, from: data) {
            let discount = json["discount"]?.stringValue ?? "0"
            return "Promo code \(code) applied — \(discount) off!"
        }
        return "That code isn't valid or has expired."
    }

    private func fetchActivePromos() async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/promotions") else { return "No promos available." }
        let (data, _) = try await URLSession.shared.data(from: url)
        if let json = try? JSONDecoder().decode([[String: String]].self, from: data) {
            return "Active promos:\n" + json.map { "· \($0["code"] ?? "") — \($0["description"] ?? "")" }.joined(separator: "\n")
        }
        return "No active promo codes right now."
    }

    private func findProduct(by name: String) -> Product? {
        let lowerName = name.lowercased()
        
        // 1. Exact or strict substring match
        if let exact = productViewModel?.products.first(where: { $0.name.localizedCaseInsensitiveContains(lowerName) }) {
            return exact
        }
        
        // 2. Fuzzy match
        let searchWords = lowerName.components(separatedBy: .whitespaces).filter { $0.count > 2 }
        if searchWords.isEmpty { return nil }
        
        // Score products based on matches
        let scored = productViewModel?.products.compactMap { product -> (Product, Int)? in
            let pName = product.name.lowercased()
            let pDesc = product.description?.lowercased() ?? ""
            let pCat = product.category?.lowercased() ?? ""
            let pTags = product.tags?.map { $0.lowercased() } ?? []
            
            var score = 0
            for word in searchWords {
                if pName.contains(word) { score += 5 }
                if pTags.contains(where: { $0.contains(word) }) { score += 4 }
                if pCat.contains(word) { score += 3 }
                if pDesc.contains(word) { score += 1 }
            }
            return score > 0 ? (product, score) : nil
        }
        
        return scored?.sorted(by: { $0.1 > $1.1 }).first?.0
    }

    // MARK: - Utilities
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }

    private func formatINR(_ usdPrice: Double) -> String {
        let inr = usdPrice * 83.5
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: inr)) ?? "\(Int(inr))"
    }

    private func allCategories() -> String {
        (productViewModel?.products.compactMap { $0.category } ?? []).joined(separator: ", ")
    }

    private func occasionToCategories(_ occasion: String) -> [String] {
        let lower = occasion.lowercased()
        if lower.contains("thanksgiving") || lower.contains("dinner party") { return ["cookware", "bakeware", "serveware", "dinnerware", "cutlery"] }
        if lower.contains("christmas") || lower.contains("holiday") { return ["bakeware", "serveware", "glassware", "kitchen accessories"] }
        return ["cookware", "dinnerware", "serveware"]
    }

    private func seasonalCategory(for month: Int) -> String {
        switch month {
        case 11, 12, 1: return "bakeware"
        case 6, 7, 8: return "outdoor entertaining"
        default: return "cookware"
        }
    }

    private func faqAnswer(for topic: String) -> String {
        let lower = topic.lowercased()
        if lower.contains("return") { return "We accept returns within 30 days of delivery. Items must be unused and in original packaging. Start a return by saying 'I want to return my order.'" }
        if lower.contains("shipping") { return "Standard delivery takes 3–5 business days. Express (1–2 days) is available at checkout." }
        if lower.contains("payment") { return "We accept all major cards, UPI, and net banking through Razorpay. Payments are processed securely — we never see your card details." }
        return "For anything else, contact us at support@hearthandtable.com — we typically respond within 4 hours."
    }

    private func buildComparison(_ a: Product, _ b: Product) -> String {
        var lines = ["Comparing \(a.name) vs \(b.name):"]
        lines.append("· Price: \(formatPrice(a.price)) vs \(formatPrice(b.price)) — \(a.price < b.price ? a.name : b.name) is cheaper")
        if let sa = a.stock, let sb = b.stock {
            lines.append("· Stock: \(sa) vs \(sb) units available")
        }
        if let ca = a.category, let cb = b.category, ca != cb {
            lines.append("· Categories differ: \(ca) vs \(cb)")
        }
        lines.append("\nI'd recommend \(a.price < b.price ? a.name : b.name) for best value.")
        return lines.joined(separator: "\n")
    }

    private func loadExpertCurated(persona: String) async throws -> [Product] {
        let system = "You are an expert curator. For the given persona, return ONLY a comma-separated list of 3-4 relevant categories from this list: \(allCategories()). No other text."
        let answer = try await callLLM(system: system, user: "Persona: \(persona)")
        let keywords = parseKeywords(from: answer)
        
        var products: [Product] = []
        for keyword in keywords {
            if let p = productViewModel?.products.first(where: { $0.category?.localizedCaseInsensitiveContains(keyword) == true || $0.name.localizedCaseInsensitiveContains(keyword) }) {
                if !products.contains(where: { $0.id == p.id }) {
                    products.append(p)
                }
            }
        }
        return Array(products.prefix(5))
    }

    private func parseKeywords(from text: String) -> [String] {
        return text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    }

    private func recipeSystemPrompt() -> String {
        "You are a culinary expert. Given a recipe, list the cookware categories needed. You MUST ONLY choose from this exact list: \(allCategories()). Return ONLY a comma-separated list. No other text."
    }

    private func suggestQuickReplies(for text: String) -> [ChatAttachment] {
        [.quickReplies(["Show recommendations", "Search products", "View my cart", "Track my order"])]
    }

    // MARK: - Message helpers
    private func append(_ msg: ChatMessage) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            messages.append(msg)
        }
    }

    private func replaceLoading(at index: Int, with message: ChatMessage) {
        guard index < messages.count else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            messages[index] = message
        }
    }

    // MARK: - Persistence
    private func saveChatHistory() {
        let toSave = Array(messages.suffix(50))
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: "chatHistory")
        }
    }

    private func loadChatHistory() {
        if let data = UserDefaults.standard.data(forKey: "chatHistory"),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = saved
        }
    }

    private func loadUserPreferences() {
        context.preferredLanguage = UserDefaults.standard.string(forKey: "chatLanguage") ?? "en"
        if let budgetVal = UserDefaults.standard.object(forKey: "chatBudget") as? Double {
            sessionBudget = budgetVal
            context.sessionBudget = budgetVal
        }
    }

    func sendWelcomeMessage() {
        guard messages.isEmpty else { return }
        let name = AuthSession.shared.currentUser?.name?.components(separatedBy: " ").first ?? ""
        let greeting = name.isEmpty ? "Hi! How can I help you today?" : "Hi \(name)! How can I help you today?"
        messages.append(ChatMessage(
            role: .assistant,
            text: greeting,
            attachments: [.quickReplies(["Show me recommendations", "Help me find a gift", "Track my order"])]
        ))
    }
}

// Simple AnyValue codable helper since AnyCodable isn't in project
enum AnyValue: Codable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case array([AnyValue])
    case dictionary([String: AnyValue])
    case null
    
    var stringValue: String? { if case .string(let s) = self { return s } else { return nil } }
    var arrayValue: [AnyValue]? { if case .array(let a) = self { return a } else { return nil } }
    var dictionaryValue: [String: AnyValue]? { if case .dictionary(let d) = self { return d } else { return nil } }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) { self = .string(x); return }
        if let x = try? container.decode(Int.self) { self = .integer(x); return }
        if let x = try? container.decode(Double.self) { self = .double(x); return }
        if let x = try? container.decode(Bool.self) { self = .boolean(x); return }
        if let x = try? container.decode([AnyValue].self) { self = .array(x); return }
        if let x = try? container.decode([String: AnyValue].self) { self = .dictionary(x); return }
        self = .null
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let x): try container.encode(x)
        case .integer(let x): try container.encode(x)
        case .double(let x): try container.encode(x)
        case .boolean(let x): try container.encode(x)
        case .array(let x): try container.encode(x)
        case .dictionary(let x): try container.encode(x)
        case .null: try container.encodeNil()
        }
    }
}
