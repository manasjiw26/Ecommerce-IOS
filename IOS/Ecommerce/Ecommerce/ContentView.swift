import SwiftUI

extension Notification.Name {
    static let goToShopTab = Notification.Name("goToShopTab")
    static let addedToCart = Notification.Name("addedToCart")
}

struct ContentView: View {
    @State private var selectedTab   = 0
    @State private var showChat      = false
    @State private var chatPulse     = false
    @State private var toastProduct: Product? = nil
    @EnvironmentObject var cartManager: CartManager

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
                    BagView()
                }
                .tabItem {
                    Image(systemName: "bag.fill")
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
            .onReceive(NotificationCenter.default.publisher(for: .goToShopTab)) { _ in
                selectedTab = 0
            }

            // Floating chat button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        showChat = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.12))
                                .frame(width: 70, height: 70)
                                .scaleEffect(chatPulse ? 1.25 : 1.0)
                                .opacity(chatPulse ? 0.0 : 0.6)
                                .animation(
                                    .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                                    value: chatPulse
                                )
                            Circle()
                                .fill(Color.black)
                                .frame(width: 58, height: 58)
                                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
                            Image(systemName: "sparkles")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 90)
                }
            }
        }
        // "Added to cart" toast — floats above tab bar
        .overlay(alignment: .top) {
            if let product = toastProduct {
                AddedToCartToast(product: product)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: toastProduct?.id)
        .sheet(isPresented: $showChat) { ChatView() }
        .task {
            await OrderManager.shared.fetchOrders()
            chatPulse = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .addedToCart)) { note in
            guard let product = note.object as? Product else { return }
            withAnimation { toastProduct = product }
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                withAnimation { toastProduct = nil }
            }
        }
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

#Preview {
    ContentView()
}
