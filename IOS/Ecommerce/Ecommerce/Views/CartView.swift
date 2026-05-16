import SwiftUI

struct CartView: View {
    @EnvironmentObject var cartManager: CartManager
    @StateObject private var occasionViewModel = OccasionViewModel()
    @State private var showingCheckout = false
    @State private var stockMap: [Int: Int] = [:]   // productId → live stock
    @State private var isCheckingStock = false

    var outOfStockItems: [CartItem] {
        cartManager.items.filter { item in
            let available = stockMap[item.product.id] ?? (item.product.stock ?? 999)
            return available < item.quantity
        }
    }

    var canCheckout: Bool {
        !cartManager.items.isEmpty && outOfStockItems.isEmpty && !isCheckingStock
    }

    var body: some View {
        Group {
            if cartManager.items.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "cart")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                    Text("Your cart is empty")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        if let occasion = occasionViewModel.currentOccasion {
                            NavigationLink(destination: OccasionSuggestionsView(occasion: occasion)) {
                                OccasionCardView(occasion: occasion)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        ForEach(cartManager.items) { item in
                            CartItemRow(
                                item: item,
                                availableStock: stockMap[item.product.id] ?? (item.product.stock ?? 999)
                            )
                            .environmentObject(cartManager)
                        }

                        if !outOfStockItems.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Some items are out of stock or exceed available quantity. Please update your cart.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        }

                        Divider()

                        HStack {
                            Text("Total")
                                .font(.title)
                                .fontWeight(.bold)
                            Spacer()
                            Text("$\(String(format: "%.2f", cartManager.total))")
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        .padding(.vertical)

                        Button(action: {
                            if UserDefaults.standard.bool(forKey: "isLoggedIn") {
                                showingCheckout = true
                            } else {
                                NotificationCenter.default.post(name: .requireAuth, object: nil)
                            }
                        }) {
                            HStack {
                                if isCheckingStock {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(canCheckout ? "Checkout" : (outOfStockItems.isEmpty ? "Checking Stock..." : "Items Out of Stock"))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canCheckout ? Color.black : Color.gray)
                            .cornerRadius(10)
                        }
                        .disabled(!canCheckout)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Cart")
        .sheet(isPresented: $showingCheckout) {
            RazorpayCheckoutView()
                .environmentObject(cartManager)
        }
        .task {
            await refreshStock()
            occasionViewModel.detectOccasion(from: cartManager.items)
        }
        .onChange(of: cartManager.items.count) { _ in
            Task { 
                await refreshStock()
                occasionViewModel.detectOccasion(from: cartManager.items)
            }
        }
    }

    private func refreshStock() async {
        guard !cartManager.items.isEmpty else { return }
        isCheckingStock = true
        let baseURL = APIService.baseURL
        for item in cartManager.items {
            guard let url = URL(string: "\(baseURL)/products/\(item.product.id)/stock") else { continue }
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let json = try? JSONDecoder().decode([String: Int].self, from: data),
               let stock = json["stock"] {
                await MainActor.run { stockMap[item.product.id] = stock }
            }
        }
        isCheckingStock = false
    }
}

struct CartItemRow: View {
    let item: CartItem
    let availableStock: Int
    @EnvironmentObject var cartManager: CartManager

    var isOutOfStock: Bool { availableStock < item.quantity }

    var body: some View {
        HStack(spacing: 16) {
            if let imageUrlString = item.product.imageUrl {
                CachedImageView(urlString: imageUrlString) { image in
                    image.resizable().scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                        .shimmer()
                }
                .id(imageUrlString)
                .overlay(
                    Group {
                        if availableStock == 0 {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.5))
                                .overlay(
                                    Text("OUT OF\nSTOCK")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                )
                        }
                    }
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.product.name)
                    .font(.headline)
                    .lineLimit(2)

                Text("$\(String(format: "%.2f", item.product.price))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if isOutOfStock {
                    Text(availableStock == 0 ? "Out of stock" : "Only \(availableStock) available")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: { cartManager.removeFromCart(product: item.product) }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.gray)
                }

                Text("\(item.quantity)")
                    .font(.headline)
                    .foregroundColor(isOutOfStock ? .red : .primary)

                Button(action: { cartManager.addToCart(product: item.product) }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(availableStock <= item.quantity ? .gray : .black)
                }
                .disabled(availableStock <= item.quantity)
            }
        }
    }
}

struct CartView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CartView()
                .environmentObject(CartManager())
        }
    }
}
