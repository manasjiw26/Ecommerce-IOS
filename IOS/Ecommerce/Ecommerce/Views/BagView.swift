import SwiftUI

struct BagView: View {
    @EnvironmentObject var cartManager: CartManager

    @StateObject private var bagVM = BagViewModel()
    @StateObject private var occasionVM = OccasionViewModel()
    @StateObject private var pairItWithVM = PairItWithViewModel()
    @StateObject private var savedVM = SavedForLaterViewModel()

    @State private var showSaved = false
    @State private var showCheckout = false

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

    var body: some View {
        List {
            if cartManager.items.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "bag")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("Your bag is empty")
                            .font(.headline)
                        Text("Add items to unlock premium recommendations and bundles.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            } else {
                Section {
                    BagIntelligenceView(
                        coach: bagVM.coach,
                        resurface: bagVM.resurface,
                        occasion: occasionVM.currentOccasion,
                        coachError: bagVM.coachError
                    )
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)

                Section("Items") {
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

                Section("Complete Your Set") {
                    BagBundleStrip(
                        bundle: bagVM.coach == nil ? nil : nil, // coach doesn’t carry products; strip uses bundle endpoint below
                        products: bagVMBundleProducts,
                        onAdd: { p in cartManager.addToCart(product: p) }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                Section("Pair it with") {
                    PairItWithSectionView(viewModel: pairItWithVM)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Bag (\(selectedItems.count))")
        .toolbar {
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
            .disabled(!canCheckout)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
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
