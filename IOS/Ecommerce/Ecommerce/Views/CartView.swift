import SwiftUI

struct CartView: View {
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var productViewModel: ProductViewModel

    @StateObject private var occasionViewModel = OccasionViewModel()
    @StateObject private var pairItWithViewModel = PairItWithViewModel()
    @StateObject private var intelligenceVM = CartIntelligenceViewModel()
    @StateObject private var savedVM = SavedForLaterViewModel()

    @State private var showingCheckout = false
    @State private var showSavedForLater = false

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
        List {
            if cartManager.items.isEmpty {
                emptyState
            } else {
                smartSections
                cartItemsSection
                stockWarningSection
                pairItWithSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Cart")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSavedForLater = true } label: {
                    Image(systemName: "bookmark")
                }
            }
        }
        .sheet(isPresented: $showingCheckout) {
            CheckoutFlowView()
                .environmentObject(cartManager)
        }
        .sheet(isPresented: $showSavedForLater) {
            SavedForLaterView(vm: savedVM)
                .environmentObject(cartManager)
        }
        .safeAreaInset(edge: .bottom) {
            if !cartManager.items.isEmpty {
                checkoutBar
            }
        }
        .refreshable {
            await refreshAll()
        }
        .task {
            await refreshAll()
        }
        .onChange(of: cartManager.items) { _ in
            Task { await refreshAll() }
        }
    }

    // MARK: - Sections

    private var emptyState: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "cart")
                    .font(.system(size: 44))
                    .foregroundColor(.secondary)
                Text("Your cart is empty")
                    .font(.headline)
                Text("Add products to see smart bundles and cart recommendations.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private var smartSections: some View {
        Group {
            if let occasion = occasionViewModel.currentOccasion {
                Section {
                    NavigationLink(destination: OccasionSuggestionsView(occasion: occasion)) {
                        OccasionCardView(occasion: occasion)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                if intelligenceVM.isLoading && intelligenceVM.cartCoach == nil {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Updating cart intelligence…")
                            .foregroundColor(.secondary)
                    }
                } else if let coach = intelligenceVM.cartCoach {
                    VStack(alignment: .leading, spacing: 6) {
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
                    .padding(.vertical, 4)
                }
            }

            if let bundle = intelligenceVM.bundles.first, !bundle.items.isEmpty {
                Section(bundle.title) {
                    VStack(alignment: .leading, spacing: 8) {
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
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            if let nudge = intelligenceVM.resurface.first {
                Section("Saved for later") {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "bookmark.fill")
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(nudge.reason)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("View saved items") { showSavedForLater = true }
                                .font(.subheadline)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var cartItemsSection: some View {
        Section("Items") {
            ForEach(cartManager.items) { item in
                CartItemRow(
                    item: item,
                    availableStock: stockMap[item.product.id] ?? (item.product.stock ?? 999)
                )
                .environmentObject(cartManager)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        for _ in 0..<max(1, item.quantity) {
                            cartManager.removeFromCart(product: item.product)
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }

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
        }
    }

    private var stockWarningSection: some View {
        Group {
            if !outOfStockItems.isEmpty {
                Section {
                    Label("Some items exceed available stock. Please adjust before checkout.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    private var pairItWithSection: some View {
        Section("Pair it with") {
            PairItWithSectionView(viewModel: pairItWithViewModel)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    private var checkoutBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(String(format: "%.2f", cartManager.total))")
                    .font(.headline)
            }
            Spacer()
            Button(action: {
                if UserDefaults.standard.bool(forKey: "isLoggedIn") {
                    showingCheckout = true
                } else {
                    NotificationCenter.default.post(name: .requireAuth, object: nil)
                }
            }) {
                if isCheckingStock {
                    ProgressView().tint(.white)
                        .frame(width: 120)
                } else {
                    Text(canCheckout ? "Checkout" : (outOfStockItems.isEmpty ? "Checking…" : "Fix items"))
                        .frame(minWidth: 120)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .disabled(!canCheckout)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Refresh

    private func refreshAll() async {
        occasionViewModel.detectOccasion(from: cartManager.items)
        pairItWithViewModel.fetchRecommendations(cartItems: cartManager.items)
        await savedVM.refresh()
        await refreshStock()
        await intelligenceVM.refresh(cartItems: cartManager.items)
    }

    private func refreshStock() async {
        guard !cartManager.items.isEmpty else {
            await MainActor.run { stockMap = [:] }
            return
        }
        isCheckingStock = true
        defer { isCheckingStock = false }

        let baseURL = APIService.baseURL
        for item in cartManager.items {
            guard let url = URL(string: "\(baseURL)/products/\(item.product.id)/stock") else { continue }
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let json = try? JSONDecoder().decode([String: Int].self, from: data),
               let stock = json["stock"] {
                await MainActor.run { stockMap[item.product.id] = stock }
            }
        }
    }
}

struct CartItemRow: View {
    let item: CartItem
    let availableStock: Int
    @EnvironmentObject var cartManager: CartManager

    var isOutOfStock: Bool { availableStock < item.quantity }

    var body: some View {
        HStack(spacing: 12) {
            if let imageUrlString = item.product.imageUrl {
                CachedImageView(urlString: imageUrlString) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(.systemGray5)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    Group {
                        if availableStock == 0 {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.black.opacity(0.45))
                                .overlay(
                                    Text("OUT\nOF\nSTOCK")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                )
                        }
                    }
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.product.name)
                    .font(.subheadline)
                    .lineLimit(2)

                Text("$\(String(format: "%.2f", item.product.price))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if isOutOfStock {
                    Text(availableStock == 0 ? "Out of stock" : "Only \(availableStock) available")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: { cartManager.removeFromCart(product: item.product) }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.secondary)
                }

                Text("\(item.quantity)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isOutOfStock ? .red : .primary)
                    .frame(minWidth: 18)

                Button(action: { cartManager.addToCart(product: item.product) }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(availableStock <= item.quantity ? .secondary : .primary)
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

