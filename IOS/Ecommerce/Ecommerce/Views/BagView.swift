import SwiftUI

// MARK: - BagView

struct BagView: View {
    @EnvironmentObject var cartManager: CartManager

    @StateObject private var bagVM       = BagViewModel()
    @StateObject private var savedVM     = SavedForLaterViewModel()

    @State private var showSaved         = false
    @State private var showCheckout      = false
    @State private var undo: UndoState?  = nil
    @State private var showExpressAlert  = false

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
        !cartManager.items.isEmpty && !hasOutOfStock && !bagVM.isCheckingStock
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if cartManager.items.isEmpty {
                    emptyState
                } else {
                    loadedCart
                }
            }
            .animation(.easeInOut(duration: 0.25), value: cartManager.items.isEmpty)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Cart")
                    .font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSaved = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bookmark")
                        if bagVM.savedCount > 0 {
                            Text("\(bagVM.savedCount)")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
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
        .alert("Express Checkout", isPresented: $showExpressAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("UPI express checkout is coming soon. Use the standard checkout for now.")
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

                Text("Free delivery on orders over ₹499")
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

    private var loadedCart: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Items
                itemsSection

                // Promo
                promoSection
                    .padding(.top, 8)

                // Order summary
                orderSummarySection
                    .padding(.top, 8)

                // Bottom padding so content clears the sticky footer
                Color.clear.frame(height: 130)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            cartFooter
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
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            undo = UndoState(product: item.product, quantity: item.quantity)
                            cartManager.removeLineItem(product: item.product)
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
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
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
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                Divider().padding(.horizontal, 14)
            }

            summaryRow(label: "Shipping", value: subtotal >= 499 ? "Free" : "₹49", valueColor: subtotal >= 499 ? .green : .primary)
            Divider().padding(.horizontal, 14)

            HStack {
                Text("Total")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                Text(formatPrice(grandTotal + (subtotal < 499 ? 49 : 0)))
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
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
            // Out-of-stock warning banner
            if hasOutOfStock {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.subheadline)
                    Text("Some items are out of stock. Remove them to continue.")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.1))
            }

            Divider()

            VStack(spacing: 10) {
                // Express checkout row
                HStack(spacing: 12) {
                    Text("Express")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    ForEach(["UPI", "GPay", "PhonePe"], id: \.self) { method in
                        Button {
                            showExpressAlert = true
                        } label: {
                            Text(method)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                // Primary CTA
                Button {
                    if UserDefaults.standard.bool(forKey: "isLoggedIn") {
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
                            Text(canCheckout
                                 ? "Checkout · \(formatPrice(grandTotal + (subtotal < 499 ? 49 : 0)))"
                                 : hasOutOfStock ? "Fix items to continue" : "Checking stock…")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canCheckout ? Color.primary : Color.secondary.opacity(0.4))
                    .foregroundColor(Color(UIColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canCheckout)
                .padding(.horizontal, 16)
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Helpers

    private func formatPrice(_ value: Double) -> String {
        "₹\(String(format: "%.0f", value))"
    }

    private func applyPromo() {
        promoApplying = true
        promoError = nil
        let error = cartManager.applyPromo(code: promoFieldText)
        withAnimation(.easeInOut(duration: 0.2)) {
            promoError = error
            if error == nil {
                promoExpanded = false
                promoFieldText = ""
            }
        }
        promoApplying = false
    }

    // MARK: - Refresh

    private func refreshAll() async {
        await savedVM.refresh()
        bagVM.savedCount = savedVM.items.count
        await bagVM.refreshStock(items: cartManager.items)
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
                        .fixedSize(horizontal: false, vertical: true)

                    Text("₹\(String(format: "%.0f", item.product.price))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Quantity stepper
                HStack(spacing: 4) {
                    Button(action: onDecrement) {
                        Image(systemName: item.quantity <= 1 ? "trash" : "minus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(item.quantity <= 1 ? .red : .primary)
                            .frame(width: 30, height: 30)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Text("\(item.quantity)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(minWidth: 22)
                        .multilineTextAlignment(.center)
                        .foregroundColor(exceedsStock ? .red : .primary)

                    Button(action: onIncrement) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(canIncrement ? .primary : .secondary)
                            .frame(width: 30, height: 30)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canIncrement)
                }
            }

            // Stock warning pill + inline actions
            if exceedsStock || isOutOfStock {
                HStack(spacing: 8) {
                    Label(
                        isOutOfStock ? "Out of stock" : "Only \(availableStock) left",
                        systemImage: "exclamationmark.circle.fill"
                    )
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityLabel(isOutOfStock ? "Out of stock" : "Only \(availableStock) left")

                    Spacer()

                    Button("Remove") { onRemove() }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)

                    Button("Notify Me") { onSaveForLater() }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.08))
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
