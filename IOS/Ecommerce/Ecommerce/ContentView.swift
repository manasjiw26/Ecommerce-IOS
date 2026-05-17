//
//  ContentView.swift
//  Ecommerce
//
//  Created by Apple on 03/05/26.
//

import SwiftUI
import Combine

struct ContentView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    @State private var selectedTab = 0
    @State private var showChat = false
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var aiPresence: AIPresenceManager
    
    // AI Button state
    @State private var shimmerRotation: Double = 0
    @State private var buttonScale: CGFloat = 1.0
    @State private var typingDotPhase: Bool = false
    @State private var bubbleContextMessage: String? = nil
    @State private var currentDragOffset: CGSize = .zero
    @State private var previousDragOffset: CGSize = .zero
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                ProductListView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Shop")
                    }
                    .tag(0)
                
                NavigationStack {
                    CartView()
                }
                .tabItem {
                    Image(systemName: "cart.fill")
                    Text("Cart")
                }
                .badge(cartManager.items.count)
                .tag(1)

                NavigationStack {
                    OrderListView()
                        .navigationTitle("Orders")
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
            
            // Floating AI button + bubble
            let isLeftAligned = previousDragOffset.width < -(UIScreen.main.bounds.width / 2)
            
            VStack(spacing: 0) {
                Spacer()
                HStack {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        // Bubble tooltip
                        AIHintBubble(isLeftAligned: isLeftAligned)
                            .environmentObject(aiPresence)
                            .padding(.trailing, 4)
                            .offset(x: isLeftAligned ? 182 : 0)

                        // The button
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

                            // Pulse ring — expands when isAIActive
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

                            // Sparkles icon
                            Image(systemName: "sparkles")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(aiPresence.isAIActive ? 18 : 0))
                                .animation(.easeInOut(duration: 0.5), value: aiPresence.isAIActive)
                        }
                        .scaleEffect(buttonScale)
                        .onTapGesture {
                            // Spring bounce feedback
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
                    .offset(x: currentDragOffset.width + previousDragOffset.width,
                            y: currentDragOffset.height + previousDragOffset.height)
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                let screenHeight = UIScreen.main.bounds.height
                                let currentY = previousDragOffset.height + value.translation.height
                                
                                // Safe area Y constraints (Stay well below status bar, stay above tab bar)
                                let minUpY = -(screenHeight - 230)
                                let maxDownY: CGFloat = 0
                                
                                let clampedY = min(max(currentY, minUpY), maxDownY)
                                currentDragOffset = CGSize(width: value.translation.width, height: clampedY - previousDragOffset.height)
                            }
                            .onEnded { value in
                                let screenWidth = UIScreen.main.bounds.width
                                let screenHeight = UIScreen.main.bounds.height
                                
                                // Predicted X based on velocity
                                let endX = previousDragOffset.width + currentDragOffset.width + (value.predictedEndTranslation.width * 0.4)
                                let leftSnap = -(screenWidth - 100)
                                let targetX = (endX < leftSnap / 2) ? leftSnap : 0
                                
                                // Predicted Y with tighter bounds
                                let endY = previousDragOffset.height + currentDragOffset.height + (value.predictedEndTranslation.height * 0.2)
                                let minUpY = -(screenHeight - 230)
                                let maxDownY: CGFloat = 0
                                let targetY = min(max(endY, minUpY), maxDownY)
                                
                                withAnimation(.interpolatingSpring(stiffness: 250, damping: 20)) {
                                    previousDragOffset = CGSize(width: targetX, height: targetY)
                                    currentDragOffset = .zero
                                }
                            }
                    )
                }
            }
        }
        .sheet(isPresented: $showChat) {
            ChatView(initialBubbleMessage: bubbleContextMessage)
        }
        .onChange(of: selectedTab) { _, newTab in
            aiPresence.resetIdleTimer()
            Task {
                await aiPresence.setBubbleForTab(newTab, cartCount: cartManager.items.count)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("openChatFromBubble"))) { notification in
            if let msg = notification.userInfo?["bubbleMessage"] as? String {
                self.bubbleContextMessage = msg
            } else {
                self.bubbleContextMessage = nil
            }
            // Add a small delay to ensure bubbleContextMessage state updates BEFORE the sheet is presented
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                showChat = true
            }
        }
        .task {
            // Shimmer rotation animation
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                shimmerRotation = 360
            }
            aiPresence.resetIdleTimer()
            await OrderManager.shared.fetchOrders()
            
            // Show initial bubble after 1.5s on first launch
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                aiPresence.showBubble(messages: ["✦ Personalizing your feed", "✦ Ask me anything ✦"])
            }
            
            // Set up notification observers
            setupNotificationObservers()
        }
    }
    
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
                        // Background pill
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 5)

                        if aiPresence.bubbleIsTyping {
                            // 3-dot typing indicator
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
                                .font(.system(size: 13, weight: .medium, design: .default))
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
                        NotificationCenter.default.post(name: Notification.Name("openChatFromBubble"), object: nil, userInfo: ["bubbleMessage": msg])
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
