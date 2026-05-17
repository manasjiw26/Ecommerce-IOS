import SwiftUI

struct CartView: View {
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var productViewModel: ProductViewModel
    @StateObject private var occasionViewModel = OccasionViewModel()
    @StateObject private var pairItWithViewModel = PairItWithViewModel()
    @StateObject private var intelligenceVM = CartIntelligenceViewModel()
    @StateObject private var savedVM = SavedForLaterViewModel()
    @State private var showingCheckout = false
    @State private var stockMap: [Int: Int] = [:]   // productId → live stock
    @State private var isCheckingStock = false
    @State private var occasion: String?
    @State private var isDetectingOccasion = false
    @State private var showSavedForLater = false

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
                    
                    Divider()
                        .padding(.vertical)
                    
                    // Always show suggestions even when empty
                    PairItWithSectionView(viewModel: pairItWithViewModel)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Occasion section — original logic, untouched
                        if let occasion = occasionViewModel.currentOccasion {
                            NavigationLink(destination: OccasionSuggestionsView(occasion: occasion)) {
                                OccasionCardView(occasion: occasion)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Smart cart coach
                        if let coach = intelligenceVM.cartCoach {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Cart Coach")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(coach.score)")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                                Text(coach.headline)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let first = coach.insights.first {
                                    Text(first.message)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(14)
                            .background(Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }

                        // Bundles / add-ons
                        if let bundle = intelligenceVM.bundles.first, !bundle.items.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(bundle.title)
                                        .font(.headline)
                                    Spacer()
                                }
                                if let why = bundle.reasoning, !why.isEmpty {
                                    Text(why)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(bundle.items.prefix(10)) { product in
                                            NavigationLink(destination: ProductDetailView(product: product)) {
                                                AIRecommendationCard(product: product)
                                                    .frame(width: 170)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }

                        // Saved resurfacing nudge
                        if let nudge = intelligenceVM.resurface.first {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundColor(.secondary)
                                    Text("Saved for later")
                                        .font(.headline)
                                    Spacer()
                                    Button("View") { showSavedForLater = true }
                                        .font(.subheadline)
                                }
                                Text(nudge.reason)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(14)
                            .background(Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }
                        
                        // Legacy/experimental "occasion insight" UI (kept commented so nothing is lost).
                        // if isDetectingOccasion || occasion != nil {
                        //     VStack(alignment: .leading, spacing: 8) {
                        //         HStack {
                        //             Image(systemName: "sparkles")
                        //                 .foregroundColor(.purple)
                        //             Text("AI Occasion Insights")
                        //                 .font(.caption)
                        //                 .fontWeight(.bold)
                        //                 .foregroundColor(.purple)
                        //         }
                        //
                        //         if isDetectingOccasion {
                        //             HStack {
                        //                 Text("Detecting your shopping occasion...")
                        //                     .font(.subheadline)
                        //                     .foregroundColor(.secondary)
                        //                 Spacer()
                        //                 ProgressView()
                        //             }
                        //         } else if let occasion = occasion {
                        //             Text("Looks like you're shopping for a")
                        //                 .font(.subheadline)
                        //                 .foregroundColor(.secondary)
                        //             Text(occasion)
                        //                 .font(.title3)
                        //                 .fontWeight(.bold)
                        //         }
                        //     }
                        //     .padding()
                        //     .frame(maxWidth: .infinity, alignment: .leading)
                        //     .background(Color.purple.opacity(0.1))
                        //     .cornerRadius(12)
                        //     .overlay(
                        //         RoundedRectangle(cornerRadius: 12)
                        //             .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        //     )
                        // }

                        ForEach(cartManager.items) { item in
                            CartItemRow(
                                item: item,
                                availableStock: stockMap[item.product.id] ?? (item.product.stock ?? 999)
                            )
                            .environmentObject(cartManager)
                            .swipeActions(edge: .trailing) {
                                if (stockMap[item.product.id] ?? (item.product.stock ?? 999)) < item.quantity {
                                    Button {
                                        Task {
                                            try? await SavedForLaterService.shared.save(
                                                deviceId: RecommendationEngine.shared.deviceId,
                                                productId: item.product.id
                                            )
                                            cartManager.removeFromCart(product: item.product)
                                            await savedVM.refresh()
                                        }
                                    } label: {
                                        Label("Save", systemImage: "bookmark")
                                    }
                                    .tint(.orange)
                                }
                            }
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
                        
                        // Might We Suggest section
                        PairItWithSectionView(viewModel: pairItWithViewModel)

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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSavedForLater = true
                } label: {
                    Image(systemName: "bookmark")
                }
            }
        }
        .sheet(isPresented: $showingCheckout) {
            RazorpayCheckoutView()
                .environmentObject(cartManager)
        }
        .sheet(isPresented: $showSavedForLater) {
            SavedForLaterView(vm: savedVM)
                .environmentObject(cartManager)
        }
        .task {
            // Priority 1: Detect Occasions (untouched)
            occasionViewModel.detectOccasion(from: cartManager.items)

            // Priority 2: Fetch AI recommendations from backend
            pairItWithViewModel.fetchRecommendations(cartItems: cartManager.items)

            // Priority 3: Stock check
            await refreshStock()
            await fetchOccasion()

            // Smart cart sections
            await intelligenceVM.refresh(cartItems: cartManager.items)
        }
        .onChange(of: cartManager.items) { _ in
            Task {
                occasionViewModel.detectOccasion(from: cartManager.items)
                pairItWithViewModel.fetchRecommendations(cartItems: cartManager.items)
                await refreshStock()
                await fetchOccasion()
                await intelligenceVM.refresh(cartItems: cartManager.items)
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

    private func fetchOccasion() async {
        let allTags = cartManager.items.compactMap { $0.product.tags }.flatMap { $0 }
        guard !allTags.isEmpty else {
            await MainActor.run { occasion = nil }
            return
        }
        
        await MainActor.run { isDetectingOccasion = true }
        
        // TODO: Plug in your CoreML model here!
        // Example: let detected = try? MyCoreMLModel(configuration: .init()).prediction(tags: allTags)
        
        // Simulating CoreML processing delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            // For now, it's just a placeholder until your model is connected
            self.occasion = "Special Occasion (CoreML Placeholder)"
            self.isDetectingOccasion = false
        }
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
