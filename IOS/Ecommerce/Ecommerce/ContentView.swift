import SwiftUI
import Combine

extension Notification.Name {
    static let goToShopTab = Notification.Name("goToShopTab")
    static let addedToCart = Notification.Name("addedToCart")
    // requireAuth, openRegistryToken, aiDidSpotProduct etc. declared in EcommerceApp.swift
}

struct ContentView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    // MARK: — State
    @State private var selectedTab       = 0
    @State private var lastAllowedTab    = 0
    @State private var showChat          = false
    @State private var toastProduct: Product? = nil
    @State private var showRegistryAuthAlert  = false
    @State private var bubbleContextMessage: String? = nil

    // AI button drag / shimmer state
    @State private var shimmerRotation:     Double   = 0
    @State private var buttonScale:         CGFloat  = 1.0
    @State private var currentDragOffset:   CGSize   = .zero
    @State private var previousDragOffset:  CGSize   = .zero
    @State private var cancellables = Set<AnyCancellable>()

    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var authSession:  AuthSession
    @EnvironmentObject var aiPresence:   AIPresenceManager

    // MARK: — Body
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                ProductListView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Shop")
                    }
                    .tag(0)

                NavigationStack { BagView() }
                    .tabItem {
                        Image(systemName: "bag.fill")
                        Text("Cart")
                    }
                    .badge(cartManager.items.count)
                    .tag(1)

                NavigationStack {
                    OrderListView().navigationTitle("Orders")
                }
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("Orders")
                }
                .tag(2)

                RegistryCoordinatorView()
                    .tabItem {
                        Image(systemName: "gift.fill")
                        Text("Registry")
                    }
                    .tag(3)
            }
            .tint(.primary)
            .onReceive(NotificationCenter.default.publisher(for: .goToShopTab)) { _ in
                selectedTab = 0
            }
            .onChange(of: selectedTab) { newValue in
                // Registry requires an authenticated user; block the tab for anonymous sessions.
                if newValue == 3 && authSession.currentUser == nil {
                    showRegistryAuthAlert = true
                    selectedTab = lastAllowedTab
                } else {
                    lastAllowedTab = newValue
                }
                // Notify AI presence about tab change for context-aware bubbles
                aiPresence.resetIdleTimer()
                Task {
                    await aiPresence.setBubbleForTab(newValue, cartCount: cartManager.items.count)
                }
            }

            // MARK: — Floating AI Button + Context Bubble
            let isLeftAligned = previousDragOffset.width < -(UIScreen.main.bounds.width / 2)

            VStack(spacing: 0) {
                Spacer()
                HStack {
                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        // Context-aware hint bubble
                        AIHintBubble(isLeftAligned: isLeftAligned)
                            .environmentObject(aiPresence)
                            .padding(.trailing, 4)
                            .offset(x: isLeftAligned ? 182 : 0)

                        // AI button
                        ZStack {
                            // Rotating shimmer ring
                            Circle()
                                .stroke(
                                    AngularGradient(
                                        colors: [.clear, .white.opacity(0.3), .clear, .white.opacity(0.15), .clear],
                                        center: .center
                                    ),
                                    lineWidth: 1.5
                                )
                                .frame(width: 68, height: 68)
                                .rotationEffect(.degrees(shimmerRotation))

                            // Pulse ring
                            Circle()
                                .fill(Color.black.opacity(0.12))
                                .frame(width: 70, height: 70)
                                .scaleEffect(aiPresence.isAIActive ? 1.4 : 1.0)
                                .opacity(aiPresence.isAIActive ? 0.0 : 0.5)
                                .animation(
                                    .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                                    value: aiPresence.isAIActive
                                )

                            // Main circle
                            Circle()
                                .fill(Color.black)
                                .frame(width: 58, height: 58)
                                .shadow(
                                    color: .black.opacity(aiPresence.isAIActive ? 0.5 : 0.22),
                                    radius: aiPresence.isAIActive ? 20 : 10,
                                    x: 0, y: 4
                                )
                                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: aiPresence.isAIActive)

                            Image(systemName: "sparkles")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(aiPresence.isAIActive ? 18 : 0))
                                .animation(.easeInOut(duration: 0.5), value: aiPresence.isAIActive)
                        }
                        .scaleEffect(buttonScale)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { buttonScale = 0.86 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { buttonScale = 1.0 }
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            aiPresence.dismissBubble()
                            showChat = true
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 90)
                    .offset(
                        x: currentDragOffset.width  + previousDragOffset.width,
                        y: currentDragOffset.height + previousDragOffset.height
                    )
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                let screenHeight = UIScreen.main.bounds.height
                                let currentY = previousDragOffset.height + value.translation.height
                                let minUpY = -(screenHeight - 230)
                                let maxDownY: CGFloat = 0
                                let clampedY = min(max(currentY, minUpY), maxDownY)
                                currentDragOffset = CGSize(width: value.translation.width, height: clampedY - previousDragOffset.height)
                            }
                            .onEnded { value in
                                let screenWidth  = UIScreen.main.bounds.width
                                let screenHeight = UIScreen.main.bounds.height
                                let endX = previousDragOffset.width + currentDragOffset.width + (value.predictedEndTranslation.width * 0.4)
                                let leftSnap = -(screenWidth - 100)
                                let targetX  = (endX < leftSnap / 2) ? leftSnap : 0
                                let endY     = previousDragOffset.height + currentDragOffset.height + (value.predictedEndTranslation.height * 0.2)
                                let targetY  = min(max(endY, -(screenHeight - 230)), 0)
                                withAnimation(.interpolatingSpring(stiffness: 250, damping: 20)) {
                                    previousDragOffset = CGSize(width: targetX, height: targetY)
                                    currentDragOffset  = .zero
                                }
                            }
                    )
                }
            }
        }
        // "Added to cart" toast
        .overlay(alignment: .top) {
            if let product = toastProduct {
                AddedToCartToast(product: product)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: toastProduct?.id)
        .sheet(isPresented: $showChat) {
            ChatView(initialBubbleMessage: bubbleContextMessage)
        }
        .alert("Sign in required", isPresented: $showRegistryAuthAlert) {
            Button("Sign In / Sign Up") {
                NotificationCenter.default.post(name: .requireAuth, object: nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please sign in to access and manage registries.")
        }
        .task {
            // Start shimmer animation
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                shimmerRotation = 360
            }
            aiPresence.resetIdleTimer()
            await OrderManager.shared.fetchOrders()
            // Initial bubble after 1.5s
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                aiPresence.showBubble(messages: ["✦ Personalizing your feed", "✦ Ask me anything ✦"])
            }
            setupNotificationObservers()
        }
        .onReceive(NotificationCenter.default.publisher(for: .addedToCart)) { note in
            guard let product = note.object as? Product else { return }
            withAnimation { toastProduct = product }
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                withAnimation { toastProduct = nil }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRegistryToken)) { _ in
            selectedTab = 3
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("openChatFromBubble"))) { notification in
            bubbleContextMessage = notification.userInfo?["bubbleMessage"] as? String
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                showChat = true
            }
        }
    }

    // MARK: — AI Context Notification Observers
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .aiDidSpotProduct)
            .receive(on: RunLoop.main)
            .sink { notification in
                let name = notification.userInfo?["name"] as? String ?? "this product"
                aiPresence.showBubble(messages: ["✦ Reading reviews for \(name)…", "✦ I have thoughts on this one"])
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .aiCartUpdated)
            .receive(on: RunLoop.main)
            .sink { _ in
                aiPresence.showBubble(messages: ["✦ Nice pick — checking for a better bundle…", "✦ Found something that pairs well 👀"])
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .aiSearchPerformed)
            .receive(on: RunLoop.main)
            .sink { _ in
                aiPresence.showBubble(messages: ["✦ Searching across all categories…", "✦ Results ranked by relevance ✦"])
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .aiCheckoutStarted)
            .receive(on: RunLoop.main)
            .sink { _ in
                aiPresence.showBubble(messages: ["✦ Checking stock one more time…", "✦ All clear — ready to order"])
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .aiRegistryViewed)
            .receive(on: RunLoop.main)
            .sink { _ in
                aiPresence.showBubble(messages: ["✦ Building your perfect registry", "✦ AI can fill gaps in your list"])
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .aiOrdersViewed)
            .receive(on: RunLoop.main)
            .sink { _ in
                aiPresence.showBubble(messages: ["✦ Tracking your deliveries", "✦ Need to return something?"])
            }
            .store(in: &cancellables)
    }
}

// MARK: - Added to Cart Toast
private struct AddedToCartToast: View {
    let product: Product

    var body: some View {
        HStack(spacing: 10) {
            if let url = product.imageUrl {
                CachedImageView(urlString: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color(.systemGray4)
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "bag.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Text("Added to cart")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white.opacity(0.85))
                .font(.system(size: 16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.88))
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - AI Hint Bubble
private struct AIHintBubble: View {
    @EnvironmentObject var aiPresence: AIPresenceManager
    @State private var typingPhase: Bool = false
    let isLeftAligned: Bool

    var body: some View {
        ZStack {
            if aiPresence.bubbleVisible {
                VStack(alignment: isLeftAligned ? .leading : .trailing, spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 5)

                        if aiPresence.bubbleIsTyping {
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle()
                                        .fill(Color.primary.opacity(0.45))
                                        .frame(width: 7, height: 7)
                                        .offset(y: typingPhase ? -4 : 0)
                                        .animation(
                                            .easeInOut(duration: 0.45)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(i) * 0.13),
                                            value: typingPhase
                                        )
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .onAppear { typingPhase = true }
                            .onDisappear { typingPhase = false }
                        } else {
                            Text(aiPresence.bubbleMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 11)
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                                .id(aiPresence.bubbleMessage)
                        }
                    }
                    .frame(maxWidth: 240)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        let msg = aiPresence.bubbleMessage
                        aiPresence.dismissBubble()
                        NotificationCenter.default.post(
                            name: Notification.Name("openChatFromBubble"),
                            object: nil,
                            userInfo: ["bubbleMessage": msg]
                        )
                    }

                    // Downward caret
                    CaretShape()
                        .fill(.ultraThinMaterial)
                        .frame(width: 14, height: 7)
                        .offset(y: -1.5)
                        .padding(isLeftAligned ? .leading : .trailing, 22)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.74), value: aiPresence.bubbleVisible)
        .animation(.easeInOut(duration: 0.25), value: aiPresence.bubbleIsTyping)
    }
}

private struct CaretShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ContentView()
}
