import SwiftUI

// MARK: - BagView

struct BagView: View {
    @EnvironmentObject var cartManager: CartManager

    @StateObject private var bagVM       = BagViewModel()
    @StateObject private var savedVM     = SavedForLaterViewModel()
    @StateObject private var addressBook = AddressBookViewModel()
    @StateObject private var occasionViewModel = OccasionViewModel()
    @StateObject private var pairItWithVM = PairItWithViewModel()

    @State private var showSaved         = false
    @State private var showCheckout      = false
    @State private var showAddressSheet  = false
    @State private var editingAddress: Address? = nil
    @State private var undo: UndoState?  = nil
    @State private var showExpressAlert  = false
    @State private var showOutOfStockAlert = false
    @State private var toastMessage: String? = nil

    // Promo
    @State private var promoFieldText    = ""
    @State private var promoExpanded     = false
    @State private var promoError: String? = nil
    @State private var promoApplying     = false

    struct UndoState: Equatable {
        let product: Product
        let quantity: Int
    }

    private var subtotal: Double {
        cartManager.items.reduce(0) { $0 + ($1.product.price * Double($1.quantity)) }
    }
    private var discount: Double { cartManager.promoDiscountAmount }
    private var grandTotal: Double { max(0, subtotal - discount) }

    private var hasOutOfStock: Bool {
        cartManager.items.contains { item in
            let available = bagVM.stockMap[item.product.id] ?? (item.product.stock ?? 999)
            return available < item.quantity
        }
    }

    private var canCheckout: Bool {
        !cartManager.items.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            Group {
                if cartManager.items.isEmpty {
                    emptyState
                } else {
                    loadedCart
                }
            }
            .animation(.easeInOut(duration: 0.25), value: cartManager.items.isEmpty)
        }
        .navigationTitle("Cart")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSaved = true
                } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(30)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showSaved) {
            SavedForLaterView(vm: savedVM)
                .presentationDetents([.medium, .large])
                .environmentObject(cartManager)
        }
        .sheet(isPresented: $showCheckout) {
            CheckoutSheetView(checkoutItems: cartManager.items, addOnTotal: 0)
                .environmentObject(cartManager)
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
                .padding(.bottom, cartManager.items.isEmpty ? 24 : 110)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: undo != nil)
            }
        }
        .overlay(alignment: .top) {
            if let message = toastMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14, weight: .bold))
                    Text(message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.88))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
            }
        }
        .alert("Express Checkout", isPresented: $showExpressAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("UPI express checkout is coming soon. Use the standard checkout for now.")
        }
        .alert("Items Out of Stock", isPresented: $showOutOfStockAlert) {
            Button("Remove Out-of-Stock Items", role: .destructive) {
                // Collect and remove all out of stock items
                let outOfStockItems = cartManager.items.filter { item in
                    let available = bagVM.stockMap[item.product.id] ?? (item.product.stock ?? 999)
                    return available == 0
                }
                for item in outOfStockItems {
                    cartManager.removeLineItem(product: item.product)
                }
                Task { await refreshAll() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Some items in your cart are currently out of stock. Would you like to remove them to proceed to checkout?")
        }
        .task { await refreshAll() }
        .onChange(of: cartManager.items) { _ in Task { await refreshAll() } }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "bag")
                    .font(.system(size: 52, weight: .ultraLight))
                    .foregroundColor(.secondary)

                Text("Your cart is empty")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Free delivery on orders over $50")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    NotificationCenter.default.post(name: .goToShopTab, object: nil)
                } label: {
                    Text("Start Shopping")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.primary)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 32)
            Spacer()

            // Below-fold: Recommendations (non-competing)
            if bagVM.savedCount > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    Button {
                        showSaved = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.secondary)
                            Text("You have \(bagVM.savedCount) saved item\(bagVM.savedCount == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                }
            }
        }
    }

    // MARK: - Loaded Cart

    private var addressBar: some View {
        Button {
            showAddressSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                if let address = addressBook.selectedAddress, !address.line1.isEmpty {
                    Text("Selected Address: \(address.fullName) - \(address.line1), \(address.city)")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                } else {
                    Text("No address selected yet")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var loadedCart: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Address Bar on top
                addressBar
                    .padding(.bottom, 4)

                // Smart Occasion Card (AI driven)
                if let occasion = occasionViewModel.currentOccasion {
                    NavigationStack {
                        NavigationLink(destination: OccasionSuggestionsView(occasion: occasion)) {
                            OccasionCardView(occasion: occasion)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // Items (White Card)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Items (\(cartManager.items.count))")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(cartManager.items) { item in
                            let available = bagVM.stockMap[item.product.id] ?? (item.product.stock ?? 999)
                            BagItemRow(
                                item: item,
                                availableStock: available,
                                onRemove: {
                                    let name = item.product.name
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        undo = UndoState(product: item.product, quantity: item.quantity)
                                        cartManager.removeLineItem(product: item.product)
                                    }
                                    withAnimation {
                                        toastMessage = "Removed \(name)"
                                    }
                                    Task {
                                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                                        withAnimation {
                                            if toastMessage == "Removed \(name)" {
                                                toastMessage = nil
                                            }
                                        }
                                    }
                                    Task {
                                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                                        if undo?.product.id == item.product.id {
                                            withAnimation { undo = nil }
                                        }
                                    }
                                },
                                onSaveForLater: {
                                    Task {
                                        try? await SavedForLaterService.shared.save(
                                            deviceId: RecommendationEngine.shared.deviceId,
                                            productId: item.product.id
                                        )
                                        cartManager.removeLineItem(product: item.product)
                                        await savedVM.refresh()
                                        bagVM.savedCount = savedVM.items.count
                                    }
                                    withAnimation {
                                        toastMessage = "Added to Watch List"
                                    }
                                    Task {
                                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                                        withAnimation {
                                            if toastMessage == "Added to Watch List" {
                                                toastMessage = nil
                                            }
                                        }
                                    }
                                },
                                onDecrement: {
                                    if item.quantity <= 1 {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            undo = UndoState(product: item.product, quantity: 1)
                                            cartManager.removeLineItem(product: item.product)
                                        }
                                        Task {
                                            try? await Task.sleep(nanoseconds: 5_000_000_000)
                                            if undo?.product.id == item.product.id {
                                                withAnimation { undo = nil }
                                            }
                                        }
                                    } else {
                                        cartManager.removeFromCart(product: item.product)
                                    }
                                },
                                onIncrement: {
                                    guard available == 0 || available >= 999 || item.quantity < available else { return }
                                    cartManager.addToCart(product: item.product)
                                }
                            )
                            .environmentObject(cartManager)
                            .padding(.horizontal, 16)
                            
                            if item.id != cartManager.items.last?.id {
                                Divider()
                                    .padding(.leading, 92)
                            }
                        }
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(14)
                }

                // Might We Suggest
                PairItWithSectionView(viewModel: pairItWithVM)

                // Promo (White Card)
                promoSection

                // Order summary (White Card)
                orderSummarySection
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(14)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            cartFooter
        }
        .sheet(isPresented: $showAddressSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select Delivery Address")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    if addressBook.addresses.isEmpty {
                        VStack(spacing: 8) {
                            Text("No saved addresses")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(addressBook.addresses) { addr in
                                Button {
                                    addressBook.select(addr.id)
                                    showAddressSheet = false
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(addr.label)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Text(addr.oneLine)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        
                                        // Edit Address Pencil
                                        Button {
                                            editingAddress = addr
                                        } label: {
                                            Image(systemName: "pencil")
                                                .foregroundColor(.secondary)
                                                .font(.subheadline)
                                                .padding(6)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        if addressBook.selectedAddressId == addr.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.black)
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                    }
                                    .padding(14)
                                    .background(Color(UIColor.secondarySystemBackground).opacity(0.38))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color(UIColor.systemBackground))
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            editingAddress = Address(label: "Home", fullName: "", phone: "", line1: "", line2: "", city: "", state: "", zip: "")
                        } label: {
                            Image(systemName: "plus")
                                .foregroundColor(.black)
                                .fontWeight(.semibold)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { showAddressSheet = false }
                    }
                }
                .background(Color(UIColor.systemBackground))
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $editingAddress) { addr in
            AddressEditSheet(
                address: addr,
                onSave: { saved in
                    addressBook.upsert(saved)
                    addressBook.select(saved.id)
                    editingAddress = nil
                },
                onCancel: { editingAddress = nil }
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Items (\(cartManager.items.count))")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.bottom, 4)

            ForEach(cartManager.items) { item in
                let available = bagVM.stockMap[item.product.id] ?? (item.product.stock ?? 999)
                BagItemRow(
                    item: item,
                    availableStock: available,
                    onRemove: {
                        let name = item.product.name
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            undo = UndoState(product: item.product, quantity: item.quantity)
                            cartManager.removeLineItem(product: item.product)
                        }
                        withAnimation {
                            toastMessage = "Removed \(name)"
                        }
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            withAnimation {
                                if toastMessage == "Removed \(name)" {
                                    toastMessage = nil
                                }
                            }
                        }
                        Task {
                            try? await Task.sleep(nanoseconds: 5_000_000_000)
                            if undo?.product.id == item.product.id {
                                withAnimation { undo = nil }
                            }
                        }
                    },
                    onSaveForLater: {
                        Task {
                            try? await SavedForLaterService.shared.save(
                                deviceId: RecommendationEngine.shared.deviceId,
                                productId: item.product.id
                            )
                            cartManager.removeLineItem(product: item.product)
                            await savedVM.refresh()
                            bagVM.savedCount = savedVM.items.count
                        }
                        withAnimation {
                            toastMessage = "Added to Watch List"
                        }
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            withAnimation {
                                if toastMessage == "Added to Watch List" {
                                    toastMessage = nil
                                }
                            }
                        }
                    },
                    onDecrement: {
                        if item.quantity <= 1 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                undo = UndoState(product: item.product, quantity: 1)
                                cartManager.removeLineItem(product: item.product)
                            }
                            Task {
                                try? await Task.sleep(nanoseconds: 5_000_000_000)
                                if undo?.product.id == item.product.id {
                                    withAnimation { undo = nil }
                                }
                            }
                        } else {
                            cartManager.removeFromCart(product: item.product)
                        }
                    },
                    onIncrement: {
                        guard available == 0 || available >= 999 || item.quantity < available else { return }
                        cartManager.addToCart(product: item.product)
                    }
                )
                .environmentObject(cartManager)

                if item.id != cartManager.items.last?.id {
                    Divider()
                        .padding(.leading, 80)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Promo Section

    private var promoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed / applied state
            if let code = cartManager.appliedPromoCode {
                HStack(spacing: 10) {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    Text(code)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    Text("applied")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Remove") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            cartManager.removePromo()
                            promoFieldText = ""
                            promoError = nil
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                }
                .padding(14)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                )
            } else {
                // Expandable promo field
                VStack(spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            promoExpanded.toggle()
                            if !promoExpanded { promoError = nil }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                            Text("Have a promo code?")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: promoExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                    }
                    .buttonStyle(.plain)

                    if promoExpanded {
                        Divider().padding(.horizontal, 14)
                        HStack(spacing: 10) {
                            TextField("Enter promo code", text: $promoFieldText)
                                .font(.subheadline)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .padding(.vertical, 10)
                            Button {
                                applyPromo()
                            } label: {
                                if promoApplying {
                                    ProgressView()
                                        .frame(width: 60)
                                } else {
                                    Text("Apply")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(width: 60)
                                }
                            }
                            .disabled(promoFieldText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || promoApplying)
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, promoError == nil ? 14 : 6)

                        if let err = promoError {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 12)
                        }
                    }
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(14)
            }
        }
    }

    // MARK: - Order Summary

    private var orderSummarySection: some View {
        VStack(spacing: 0) {
            summaryRow(label: "Subtotal", value: formatPrice(subtotal))
            Divider().padding(.horizontal, 14)

            if discount > 0, let code = cartManager.appliedPromoCode {
                summaryRow(label: "Promo (\(code))", value: "−\(formatPrice(discount))", valueColor: .green)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
                Divider().padding(.horizontal, 14)
                    .transition(.opacity)
            }

            summaryRow(label: "Shipping", value: subtotal >= 50 ? "Free" : "$5.00", valueColor: subtotal >= 50 ? .green : .primary)
            Divider().padding(.horizontal, 14)

            HStack {
                Text("Total")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                Text(formatPrice(grandTotal + (subtotal < 50 ? 5 : 0)))
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func summaryRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Footer

    private var cartFooter: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 10) {
                // Express checkout row
//                HStack(spacing: 12) {
//                    Text("Express")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                    Spacer()
//                    ForEach(["UPI", "GPay", "PhonePe"], id: \.self) { method in
//                        Button {
//                            showExpressAlert = true
//                        } label: {
//                            Text(method)
//                                .font(.caption)
//                                .fontWeight(.semibold)
//                                .padding(.horizontal, 12)
//                                .padding(.vertical, 6)
//                                .background(Color(UIColor.secondarySystemGroupedBackground))
//                                .clipShape(Capsule())
//                        }
//                        .buttonStyle(.plain)
//                    }
//                }
//                .padding(.horizontal, 16)

                // Primary CTA
                Button {
                    if hasOutOfStock {
                        showOutOfStockAlert = true
                    } else if UserDefaults.standard.bool(forKey: "isLoggedIn") {
                        showCheckout = true
                    } else {
                        NotificationCenter.default.post(name: .requireAuth, object: nil)
                    }
                } label: {
                    HStack {
                        if bagVM.isCheckingStock {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Checkout · \(formatPrice(grandTotal + (subtotal < 50 ? 5 : 0)))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(hasOutOfStock ? Color.gray.opacity(0.6) : Color.black)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(bagVM.isCheckingStock || cartManager.items.isEmpty)
                .padding(.horizontal, 16)
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Helpers

    private func formatPrice(_ value: Double) -> String {
        "$\(String(format: "%.2f", value))"
    }

    private func applyPromo() {
        promoApplying = true
        promoError = nil
        
        Task {
            let error = await cartManager.applyPromo(code: promoFieldText)
            
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    promoError = error
                    if error == nil {
                        promoExpanded = false
                        promoFieldText = ""
                        toastMessage = "Promo Applied Successfully!"
                    }
                }
                
                // Clear toast after 2.5 seconds
                if error == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { toastMessage = nil }
                    }
                }
                promoApplying = false
            }
        }
    }

    // MARK: - Refresh

    private func refreshAll() async {
        await savedVM.refresh()
        bagVM.savedCount = savedVM.items.count
        await bagVM.refreshStock(items: cartManager.items)
        await addressBook.fetchAddressFromBackend()
        occasionViewModel.detectOccasion(from: cartManager.items)
        pairItWithVM.fetchRecommendations(cartItems: cartManager.items)
    }
}

// MARK: - BagItemRow

private struct BagItemRow: View {
    let item: CartItem
    let availableStock: Int
    let onRemove: () -> Void
    let onSaveForLater: () -> Void
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    @EnvironmentObject var cartManager: CartManager

    private var isOutOfStock: Bool { availableStock == 0 }
    private var exceedsStock: Bool { availableStock > 0 && availableStock < 999 && item.quantity > availableStock }
    private var canIncrement: Bool { availableStock == 0 || availableStock >= 999 || item.quantity < availableStock }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                NavigationLink(destination: ProductDetailView(product: item.product)) {
                    HStack(spacing: 12) {
                        // Thumbnail
                        if let url = item.product.imageUrl {
                            CachedImageView(urlString: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color(.systemGray5)
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                Group {
                                    if isOutOfStock {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.black.opacity(0.45))
                                            .overlay(
                                                Text("OUT\nOF\nSTOCK")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .multilineTextAlignment(.center)
                                            )
                                    }
                                }
                            )
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.product.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("$\(String(format: "%.2f", item.product.price))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Quantity stepper
                HStack(spacing: 12) {
                    Button(action: onDecrement) {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.black)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Text("\(item.quantity)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(minWidth: 16)
                        .multilineTextAlignment(.center)
                        .foregroundColor(exceedsStock ? .red : .primary)

                    Button(action: onIncrement) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(canIncrement ? Color.black : Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canIncrement)
                }
            }

            // Stock warning pill + inline actions
            if exceedsStock || isOutOfStock {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(isOutOfStock ? "Out of stock" : "Only \(availableStock) left")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Remove") { onRemove() }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)

                    Text("|")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.4))

                    Button("Notify Me") { onSaveForLater() }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onSaveForLater()
            } label: {
                Label("Save", systemImage: "bookmark")
            }
            .tint(.orange)
        }
    }
}

// MARK: - UndoSnackbar

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
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}
