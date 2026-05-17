import SwiftUI

struct CartView: View {
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var aiPresence: AIPresenceManager

    @StateObject private var occasionViewModel = OccasionViewModel()
    @StateObject private var pairItWithViewModel = PairItWithViewModel()
    @StateObject private var intelligenceVM = CartIntelligenceViewModel()
    @EnvironmentObject var savedVM: SavedForLaterViewModel
    @EnvironmentObject var addressBook: AddressBookViewModel

    @State private var showingCheckout = false
    @State private var showSavedForLater = false

    @State private var stockMap: [Int: Int] = [:]   // productId → live stock
    @State private var isCheckingStock = false
    @State private var selectedProductIds: Set<Int> = []
    @State private var previousCartProductIds: Set<Int> = []

    @State private var undoBanner: UndoBannerState? = nil

    struct UndoBannerState: Equatable {
        let product: Product
        let quantity: Int
    }

    var outOfStockItems: [CartItem] {
        cartManager.items.filter { item in
            let available = stockMap[item.product.id] ?? (item.product.stock ?? 999)
            return available < item.quantity
        }
    }

    var selectedItems: [CartItem] {
        cartManager.items.filter { selectedProductIds.contains($0.product.id) }
    }

    var selectedTotal: Double {
        selectedItems.reduce(0) { $0 + ($1.product.price * Double($1.quantity)) }
    }

    var outOfStockSelected: [CartItem] {
        selectedItems.filter { item in
            let available = stockMap[item.product.id] ?? (item.product.stock ?? 999)
            return available < item.quantity
        }
    }

    var canCheckout: Bool {
        !selectedItems.isEmpty && outOfStockSelected.isEmpty && !isCheckingStock
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
            CheckoutFlowView(checkoutItems: selectedItems)
                .environmentObject(cartManager)
                .environmentObject(addressBook)
        }
        .sheet(isPresented: $showSavedForLater) {
            SavedForLaterView()
                .environmentObject(cartManager)
                .environmentObject(savedVM)
        }
        .safeAreaInset(edge: .bottom) {
            if !cartManager.items.isEmpty {
                checkoutBar
            }
        }
        .overlay(alignment: .bottom) {
            if let banner = undoBanner {
                HStack(spacing: 12) {
                    Text("Removed \(banner.product.name)")
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Button("Undo") {
                        cartManager.addToCart(product: banner.product, quantity: banner.quantity)
                        undoBanner = nil
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
                .contentShape(Rectangle())
                .overlay(alignment: .leading) {
                    Button {
                        toggleSelected(productId: item.product.id)
                    } label: {
                        Image(systemName: selectedProductIds.contains(item.product.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedProductIds.contains(item.product.id) ? .accentColor : .secondary)
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.leading, 6)
                            .padding(.trailing, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(selectedProductIds.contains(item.product.id) ? "Selected" : "Not selected")
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        Task {
                            try? await SavedForLaterService.shared.save(
                                deviceId: RecommendationEngine.shared.deviceId,
                                productId: item.product.id
                            )
                            selectedProductIds.remove(item.product.id)
                            cartManager.removeLineItem(product: item.product)
                            await savedVM.refresh()
                        }
                    } label: {
                        Label("Save", systemImage: "bookmark")
                    }
                    .tint(.orange)

                    Button(role: .destructive) {
                        selectedProductIds.remove(item.product.id)
                        undoBanner = UndoBannerState(product: item.product, quantity: item.quantity)
                        cartManager.removeLineItem(product: item.product)
                        Task {
                            try? await Task.sleep(nanoseconds: 4_500_000_000)
                            if undoBanner?.product.id == item.product.id { undoBanner = nil }
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
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
                Text("$\(String(format: "%.2f", selectedTotal))")
                    .font(.headline)
            }
            Spacer()
            Button(action: {
                if AuthSession.shared.isGuest {
                    NotificationCenter.default.post(name: .requireAuth, object: nil)
                } else {
                    showingCheckout = true
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
        aiPresence.isAIActive = true
        defer { aiPresence.isAIActive = false }

        // Keep selection stable while cart changes; default newly-added items to selected.
        let current = Set(cartManager.items.map { $0.product.id })
        if selectedProductIds.isEmpty {
            selectedProductIds = current
        } else {
            let newIds = current.subtracting(previousCartProductIds)
            selectedProductIds = selectedProductIds.intersection(current).union(newIds)
        }
        previousCartProductIds = current

        occasionViewModel.detectOccasion(from: cartManager.items)
        pairItWithViewModel.fetchRecommendations(cartItems: cartManager.items)
        await savedVM.refresh()
        await refreshStock()
        await intelligenceVM.refresh(cartItems: cartManager.items)

        // Notify AI bubble
        if !cartManager.items.isEmpty {
            NotificationCenter.default.post(name: .aiCartUpdated, object: nil)
        }
    }

    private func toggleSelected(productId: Int) {
        if selectedProductIds.contains(productId) {
            selectedProductIds.remove(productId)
        } else {
            selectedProductIds.insert(productId)
        }
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
    var canIncrement: Bool {
        // If stock is unknown (we use a high fallback), allow.
        // If stock is known, cap at availableStock.
        if availableStock >= 999 { return true }
        if availableStock == 0 { return false }
        return item.quantity < availableStock
    }

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
                .frame(width: 32, height: 32)

                Text("\(item.quantity)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isOutOfStock ? .red : .primary)
                    .frame(minWidth: 18)

                Button(action: {
                    guard canIncrement else { return }
                    cartManager.addToCart(product: item.product)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(canIncrement ? .primary : .secondary)
                }
                .frame(width: 32, height: 32)
                .disabled(!canIncrement)
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
