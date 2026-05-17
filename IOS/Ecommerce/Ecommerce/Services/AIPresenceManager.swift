import SwiftUI
import Combine
import Foundation

// MARK: - AI Presence Manager
// Global singleton managing all AI ambient state — bubble messages,
// typing indicators, active computation state, and idle timers.
@MainActor
final class AIPresenceManager: ObservableObject {
    // MARK: - Published State
    @Published var bubbleMessage: String = ""
    @Published var bubbleVisible: Bool = false
    @Published var bubbleIsTyping: Bool = false
    @Published var isAIActive: Bool = false
    @Published var lastViewedProduct: Product? = nil
    @Published var scanStatusMessages: [String] = []
    @Published var geminiAvailable: Bool = false

    // MARK: - Private Timers
    private var bubbleTimer: Timer?
    private var idleTimer: Timer?
    private var cycleTimer: Timer?
    private var currentPool: [String] = []
    private var poolIndex: Int = 0

    // MARK: - Local Fallback Pools
    private let localPools: [String: [String]] = [
        "shop_browse":    ["✦ Personalizing your feed", "✦ Scanning 200+ products for you", "✦ 3 new arrivals match your taste", "✦ Prices verified just now"],
        "product_detail": ["✦ Reading reviews for this", "✦ I have thoughts on this", "✦ Checking for a better deal", "✦ Analyzing similar products"],
        "cart_empty":     ["✦ Cart is empty — want ideas?", "✦ I can build a cart from a vibe"],
        "cart_has_items": ["✦ Optimizing your cart", "✦ Nice picks — found a bundle 👀", "✦ Want to complete the set?"],
        "orders":         ["✦ Tracking your deliveries", "✦ Need to return something?", "✦ I can reorder instantly"],
        "registry":       ["✦ Building your perfect registry", "✦ I can find gifts in any budget", "✦ Analyzing wish patterns"],
        "checkout":       ["✦ Checking stock one more time", "✦ All clear — ready to order"],
        "search_results": ["✦ Results ranked by relevance", "✦ Found across all categories"],
        "idle":           ["✦ Still here if you need me", "✦ Ask me anything ✦"]
    ]

    // MARK: - Init
    init() {
        Task { await checkGeminiHealth() }
        resetIdleTimer()
    }

    // MARK: - Health Check
    func checkGeminiHealth() async {
        guard let url = URL(string: "\(Config.apiBaseURL)/ai/presence/health") else {
            geminiAvailable = false
            return
        }
        do {
            var request = URLRequest(url: url, timeoutInterval: 5)
            request.httpMethod = "GET"
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let gemini = json["gemini"] as? Bool {
                geminiAvailable = gemini
            }
        } catch {
            geminiAvailable = false
        }
    }

    // MARK: - Fetch Hint from Server
    func fetchHint(context: String, productName: String? = nil, productCategory: String? = nil, cartCount: Int = 0, tab: Int = 0) async -> String {
        guard let url = URL(string: "\(Config.apiBaseURL)/ai/presence/hint") else {
            return randomLocal(context)
        }
        do {
            var request = URLRequest(url: url, timeoutInterval: 3)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var body: [String: Any] = [
                "context": context,
                "cart_count": cartCount,
                "tab": tab,
                "device_id": RecommendationEngine.shared.deviceId
            ]
            if let name = productName { body["product_name"] = name }
            if let cat = productCategory { body["product_category"] = cat }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let hint = json["hint"] as? String {
                return hint
            }
        } catch {
            // Silently fall back to local pool
        }
        return randomLocal(context)
    }

    private func randomLocal(_ context: String) -> String {
        let pool = localPools[context] ?? localPools["idle"]!
        return pool.randomElement() ?? "✦ Still here if you need me"
    }

    // MARK: - Show Bubble (Local Messages)
    func showBubble(messages: [String], cycleEvery: TimeInterval = 8, autoDismiss: TimeInterval = 5) {
        // Cancel existing timers
        bubbleTimer?.invalidate()
        cycleTimer?.invalidate()
        bubbleTimer = nil
        cycleTimer = nil

        currentPool = messages
        poolIndex = 0

        // Start with typing indicator
        bubbleIsTyping = true
        withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) {
            bubbleVisible = true
        }

        // After 0.8s, show first message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            self.bubbleIsTyping = false
            withAnimation(.easeInOut(duration: 0.25)) {
                self.bubbleMessage = messages.first ?? ""
            }
        }

        // If multiple messages, cycle through them
        if messages.count > 1 {
            cycleTimer = Timer.scheduledTimer(withTimeInterval: cycleEvery, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.bubbleIsTyping = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.poolIndex = (self.poolIndex + 1) % self.currentPool.count
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.bubbleMessage = self.currentPool[self.poolIndex]
                        }
                        self.bubbleIsTyping = false
                    }
                }
            }
        }

        // Auto-dismiss
        bubbleTimer = Timer.scheduledTimer(withTimeInterval: autoDismiss, repeats: false) { [weak self] _ in
            guard let mgr = self else { return }
            Task { @MainActor in
                mgr.dismissBubble()
            }
        }
    }

    // MARK: - Show Bubble Async (Server-driven)
    func showBubbleAsync(context: String, productName: String? = nil, productCategory: String? = nil, cartCount: Int = 0, tab: Int = 0) {
        Task {
            let hint = await fetchHint(context: context, productName: productName, productCategory: productCategory, cartCount: cartCount, tab: tab)
            showBubble(messages: [hint])
        }
    }

    // MARK: - Dismiss Bubble
    func dismissBubble() {
        bubbleTimer?.invalidate()
        cycleTimer?.invalidate()
        bubbleTimer = nil
        cycleTimer = nil
        bubbleIsTyping = false
        withAnimation(.easeOut(duration: 0.25)) {
            bubbleVisible = false
        }
    }

    // MARK: - Idle Timer
    func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            guard let mgr = self else { return }
            Task { @MainActor in
                guard !mgr.bubbleVisible else { return }
                mgr.showBubble(messages: ["✦ Still here if you need me"])
            }
        }
    }

    // MARK: - Tab-Based Bubble
    func setBubbleForTab(_ tab: Int, cartCount: Int) async {
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        switch tab {
        case 0:
            showBubbleAsync(context: "shop_browse", tab: 0)
        case 1:
            if cartCount == 0 {
                showBubble(messages: ["✦ Cart is empty — want ideas?"])
            } else {
                showBubbleAsync(context: "cart_has_items", cartCount: cartCount)
            }
        case 2:
            showBubble(messages: ["✦ Tracking your deliveries", "✦ Need to return something?", "✦ I can reorder instantly"])
        case 3:
            showBubble(messages: ["✦ Building your perfect registry", "✦ I can find gifts in any budget", "✦ Analyzing wish patterns"])
        default:
            break
        }
    }
}

// MARK: - AI Notification Names
extension Notification.Name {
    static let aiDidSpotProduct   = Notification.Name("aiDidSpotProduct")
    static let aiCartUpdated      = Notification.Name("aiCartUpdated")
    static let aiSearchPerformed  = Notification.Name("aiSearchPerformed")
    static let aiCheckoutStarted  = Notification.Name("aiCheckoutStarted")
    static let aiRegistryViewed   = Notification.Name("aiRegistryViewed")
    static let aiOrdersViewed     = Notification.Name("aiOrdersViewed")
}
