import SwiftUI

struct BagView: View {
    @EnvironmentObject var cartManager: CartManager

    @StateObject private var bagVM = BagViewModel()
    @StateObject private var occasionVM = OccasionViewModel()
    @StateObject private var pairItWithVM = PairItWithViewModel()
    @StateObject private var savedVM = SavedForLaterViewModel()

    @State private var showSaved = false
    @State private var showCheckout = false
    @State private var scrollToAddOnsTick: Int = 0

    @State private var undo: UndoState? = nil

    struct UndoState: Equatable {
        let product: Product
        let quantity: Int
    }

    private var selectedItems: [CartItem] { bagVM.selectedItems(from: cartManager.items) }
    private var selectedSubtotal: Double { bagVM.subtotal(for: selectedItems) }

    private var outOfStockSelected: [CartItem] {
        selectedItems.filter { item in
            let available = bagVM.stockMap[item.product.id] ?? (item.product.stock ?? 999)
            return available < item.quantity
        }
    }

    private var canCheckout: Bool {
        !selectedItems.isEmpty && outOfStockSelected.isEmpty && !bagVM.isCheckingStock
    }

    private var heroImageUrl: String? {
        // Prefer a real product image from the bag; fall back to a stable demo image.
        cartManager.items.first?.product.imageUrl
            ?? "https://res.cloudinary.com/dl7sh9osm/image/upload/f_auto,q_auto/v1778918763/jason_briscoe_kitchen.jpg"
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if cartManager.items.isEmpty {
                    Section {
                        BagHeroHeader(
                            imageUrl: heroImageUrl,
                            eyebrow: "THE SHOPPING BAG",
                            title: "Start with something you love.",
                            subtitle: "Add a few essentials and we’ll build bundles and smart add-ons around your picks.",
                            height: 300
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }

                    Section {
                        VStack(spacing: 14) {
                            Button {
                                NotificationCenter.default.post(name: .goToShopTab, object: nil)
                            } label: {
                                Label("Shop Bestsellers", systemImage: "bag.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.black)
                            .clipShape(Capsule())
                            .controlSize(.large)

                            Button {
                                showSaved = true
                            } label: {
                                Label("View Saved Items", systemImage: "bookmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.primary)
                            .clipShape(Capsule())
                            .controlSize(.large)
                        }
                        .padding(.vertical, 8)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                } else {
                    // Hero header (Registry-style)
                    Section {
                        BagHeroHeader(
                            imageUrl: heroImageUrl,
                            eyebrow: "THE SHOPPING BAG",
                            title: "Complete your kitchen, beautifully.",
                            subtitle: nil,
                            height: 260
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }

                    // Primary actions row
                    Section {
                        HStack(spacing: 14) {
                            Button {
                                showSaved = true
                            } label: {
                                Label("Saved", systemImage: "bookmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.black)
                            .clipShape(Capsule())

                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    proxy.scrollTo("bag_addons_anchor", anchor: .top)
                                }
                            } label: {
                                Label("Complete Your Set", systemImage: "sparkles")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.black)
                            .clipShape(Capsule())
                        }
                        .padding(.vertical, 6)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                    }

                    Section {
                        BagIntelligenceView(
                            coach: bagVM.coach,
                            resurface: bagVM.resurface,
                            occasion: occasionVM.currentOccasion,
                            coachError: bagVM.coachError,
                            onOpenSaved: { showSaved = true },
                            onOpenAddOns: {
                                scrollToAddOnsTick += 1
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    proxy.scrollTo("bag_addons_anchor", anchor: .top)
                                }
                            }
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)

                    Section(header:
                        Text("My Bag")
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .textCase(nil)
                    ) {
                        ForEach(cartManager.items) { item in
                            BagItemRow(
                                item: item,
                                availableStock: bagVM.stockMap[item.product.id] ?? (item.product.stock ?? 999),
                                isSelected: bagVM.selectedProductIds.contains(item.product.id),
                                onToggleSelected: { bagVM.selectedProductIds.toggle(item.product.id) },
                                isEngravingOn: bagVM.addOnEngraving.contains(item.product.id),
                                onToggleEngraving: { bagVM.addOnEngraving.toggle(item.product.id) },
                                isProtectionOn: bagVM.addOnProtection.contains(item.product.id),
                                onToggleProtection: { bagVM.addOnProtection.toggle(item.product.id) },
                                onSaveForLater: {
                                    Task {
                                        try? await SavedForLaterService.shared.save(
                                            deviceId: RecommendationEngine.shared.deviceId,
                                            productId: item.product.id
                                        )
                                        bagVM.selectedProductIds.remove(item.product.id)
                                        cartManager.removeLineItem(product: item.product)
                                        await savedVM.refresh()
                                        bagVM.savedCount = savedVM.items.count
                                    }
                                }
                            )
                            .environmentObject(cartManager)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task {
                                        try? await SavedForLaterService.shared.save(
                                            deviceId: RecommendationEngine.shared.deviceId,
                                            productId: item.product.id
                                        )
                                        bagVM.selectedProductIds.remove(item.product.id)
                                        cartManager.removeLineItem(product: item.product)
                                        await savedVM.refresh()
                                        bagVM.savedCount = savedVM.items.count
                                    }
                                } label: {
                                    Label("Save", systemImage: "bookmark")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    bagVM.selectedProductIds.remove(item.product.id)
                                    undo = UndoState(product: item.product, quantity: item.quantity)
                                    cartManager.removeLineItem(product: item.product)
                                    Task {
                                        try? await Task.sleep(nanoseconds: 4_500_000_000)
                                        if undo?.product.id == item.product.id { undo = nil }
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Section(header:
                        Text("Complete Your Set")
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .textCase(nil)
                    ) {
                        Color.clear
                            .frame(height: 1)
                            .id("bag_addons_anchor")
                        BagBundleStrip(
                            bundle: bagVM.coach == nil ? nil : nil,
                            products: bagVMBundleProducts,
                            onAdd: { p in cartManager.addToCart(product: p) }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Bag (\(selectedItems.count))")
                    .font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSaved = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bookmark")
                        if bagVM.savedCount > 0 {
                            Text("\(bagVM.savedCount)")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                                .offset(x: 10, y: -10)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSaved) {
            SavedForLaterView(vm: savedVM)
                .presentationDetents([.medium, .large])
                .environmentObject(cartManager)
        }
        .sheet(isPresented: $showCheckout) {
            CheckoutSheetView(checkoutItems: selectedItems, addOnTotal: selectedAddOnTotal)
                .environmentObject(cartManager)
        }
        .safeAreaInset(edge: .bottom) {
            if !cartManager.items.isEmpty {
                BagFooter(
                    subtotal: selectedSubtotal,
                    canCheckout: canCheckout,
                    isChecking: bagVM.isCheckingStock,
                    onCheckout: { showCheckout = true }
                )
            }
        }
        .overlay(alignment: .bottom) {
            if let undo {
                UndoSnackbar(
                    text: "Removed \(undo.product.name)",
                    onUndo: {
                        cartManager.addToCart(product: undo.product, quantity: undo.quantity)
                        self.undo = nil
                    }
                )
                .padding(.bottom, 86)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { await refreshAll() }
        .onChange(of: cartManager.items) { _ in Task { await refreshAll() } }
    }

    // MARK: - Bundles
    @State private var bagVMBundleProducts: [Product] = []

    private var selectedAddOnTotal: Double {
        let engraving = selectedItems.reduce(0) { $0 + (bagVM.addOnEngraving.contains($1.product.id) ? 15.0 * Double($1.quantity) : 0) }
        let protection = selectedItems.reduce(0) { $0 + (bagVM.addOnProtection.contains($1.product.id) ? 49.0 : 0) }
        return engraving + protection
    }

    private func refreshBundles() async {
        do {
            // Use bundle-build with product ids + theme/budget for accessory picks.
            let resp = try await CartIntelligenceService.shared.bundleBuild(theme: "complete your set", budget: 250, activeItemIds: selectedItems.map { $0.product.id }, deviceId: RecommendationEngine.shared.deviceId)
            bagVMBundleProducts = resp.products
        } catch {
            bagVMBundleProducts = []
        }
    }

    private func refreshAll() async {
        await savedVM.refresh()
        bagVM.savedCount = savedVM.items.count

        bagVM.syncSelection(with: cartManager.items)
        await bagVM.refreshStock(items: cartManager.items)
        bagVM.autoDeselectOverStock(items: cartManager.items)

        occasionVM.detectOccasion(from: cartManager.items)
        pairItWithVM.fetchRecommendations(cartItems: selectedItems)

        await bagVM.refreshIntelligence(selectedItems: selectedItems)
        await refreshBundles()
    }
}

private struct BagFooter: View {
    let subtotal: Double
    let canCheckout: Bool
    let isChecking: Bool
    let onCheckout: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Subtotal")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(String(format: "%.2f", subtotal))")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            Spacer()
            Button(action: onCheckout) {
                if isChecking {
                    ProgressView().tint(.white).frame(width: 130)
                } else {
                    Text(canCheckout ? "Checkout" : "Fix items")
                        .frame(minWidth: 130)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .clipShape(Capsule())
            .controlSize(.large)
            .disabled(!canCheckout)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

private struct BagHeroHeader: View {
    let imageUrl: String?
    let eyebrow: String
    let title: String
    let subtitle: String?
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageUrl {
                CachedImageView(urlString: imageUrl) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color(.systemGray5)
                }
                .frame(height: height)
                .clipped()
            } else {
                Color(.systemGray5)
                    .frame(height: height)
            }

            LinearGradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .frame(height: height)

            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.92))
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
    }
}

private struct UndoSnackbar: View {
    let text: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            Button("Undo", action: onUndo)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 16)
    }
}

private struct BagBundleStrip: View {
    let bundle: CartBundle?
    let products: [Product]
    let onAdd: (Product) -> Void

    var body: some View {
        if products.isEmpty {
            Text("No add-ons right now.")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(products.prefix(12)) { p in
                        VStack(alignment: .leading, spacing: 8) {
                            AIRecommendationCard(product: p)
                                .frame(width: 170)
                            Button {
                                onAdd(p)
                            } label: {
                                Text("+ Add")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(width: 170)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct BagItemRow: View {
    let item: CartItem
    let availableStock: Int
    let isSelected: Bool
    let onToggleSelected: () -> Void

    let isEngravingOn: Bool
    let onToggleEngraving: () -> Void
    let isProtectionOn: Bool
    let onToggleProtection: () -> Void

    let onSaveForLater: () -> Void

    @EnvironmentObject var cartManager: CartManager

    private var exceedsStock: Bool { availableStock < item.quantity }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button(action: onToggleSelected) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)

                if let url = item.product.imageUrl {
                    CachedImageView(urlString: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: { Color(.systemGray5) }
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.product.name)
                        .font(.subheadline)
                        .lineLimit(2)
                    Text("$\(String(format: "%.2f", item.product.price))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button { cartManager.removeFromCart(product: item.product) } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 32, height: 32)

                    Text("\(item.quantity)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(minWidth: 18)

                    Button { cartManager.addToCart(product: item.product) } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(item.quantity < availableStock ? .primary : .secondary)
                    }
                    .frame(width: 32, height: 32)
                    .disabled(availableStock != 0 && availableStock < 999 && item.quantity >= availableStock)
                }
            }

            if exceedsStock {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(availableStock == 0 ? "Out of stock" : "Only \(availableStock) available")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button("Save for Later", action: onSaveForLater)
                        .font(.caption)
                        .buttonStyle(.bordered)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: .init(get: { isEngravingOn }, set: { _ in onToggleEngraving() })) {
                    Text("Add Custom Engraving (+$15.00)")
                        .font(.caption)
                }
                Toggle(isOn: .init(get: { isProtectionOn }, set: { _ in onToggleProtection() })) {
                    Text("Add Appliance Protection Plan")
                        .font(.caption)
                }
            }
            .toggleStyle(.switch)
        }
        .padding(.vertical, 4)
    }
}

private extension Set where Element == Int {
    mutating func toggle(_ id: Int) {
        if contains(id) { remove(id) } else { insert(id) }
    }
}
