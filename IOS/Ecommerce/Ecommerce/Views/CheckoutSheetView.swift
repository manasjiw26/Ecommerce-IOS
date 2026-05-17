import SwiftUI

struct CheckoutSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var cartManager: CartManager

    let checkoutItems: [CartItem]
    let addOnTotal: Double

    @StateObject private var addressBook = AddressBookViewModel()
    @State private var editingAddress: Address? = nil
    @State private var step: CheckoutStep = .address

    @State private var shippingSpeed: ShippingSpeed = .standard
    @State private var paymentMethod: PaymentMethod = .mockPay

    @State private var fullName: String = AuthSession.shared.currentUser?.name ?? ""
    @State private var email: String = AuthSession.shared.currentUser?.email ?? ""
    @State private var phone: String = ""
    @State private var address1: String = ""
    @State private var address2: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zip: String = ""

    @State private var isPlacing = false
    @State private var errorMessage: String? = nil
    @State private var confirmation: Confirmation? = nil
    @State private var showRazorpay = false

    enum CheckoutStep: Int, CaseIterable {
        case address = 0
        case payment = 1
        case review = 2
    }

    enum ShippingSpeed: String, CaseIterable, Identifiable {
        case standard  = "Standard · Free"
        case express   = "Express · ₹149"
        case overnight = "Next Day · ₹299"
        var id: String { rawValue }
        var fee: Double {
            switch self {
            case .standard: return 0
            case .express: return 149
            case .overnight: return 299
            }
        }
    }

    enum PaymentMethod: String, CaseIterable, Identifiable {
        case upi      = "UPI / GPay"
        case razorpay = "Razorpay"
        case mockPay  = "Mock Pay"
        case cod      = "Cash on Delivery"
        var id: String { rawValue }
    }

    struct Confirmation: Equatable {
        let orderId: String
        let total: Double
        let paymentId: String
    }

    private var itemsSubtotal: Double {
        checkoutItems.reduce(0) { $0 + ($1.product.price * Double($1.quantity)) }
    }
    private var discount: Double { cartManager.promoDiscountAmount }
    private var grandTotal: Double {
        max(0, itemsSubtotal - discount) + addOnTotal + shippingSpeed.fee
    }
    private func fmt(_ v: Double) -> String { "₹\(String(format: "%.0f", v))" }

    private var addressValid: Bool {
        !address1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !zip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                if let c = confirmation {
                    confirmationView(c)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    VStack(spacing: 0) {
                        stepIndicator
                        ScrollView {
                            VStack(spacing: 16) {
                                switch step {
                                case .address: addressStep
                                case .payment: paymentStep
                                case .review:  reviewStep
                                }
                            }
                            .padding(16)
                            .padding(.bottom, 110)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step == .address || confirmation != nil {
                        Button("Close") { dismiss() }
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                step = CheckoutStep(rawValue: step.rawValue - 1) ?? .address
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if confirmation == nil { ctaBar }
            }
        }
        .fullScreenCover(isPresented: $showRazorpay) {
            RazorpayPaymentCaptureView(
                amount: grandTotal,
                onSuccess: { pid in
                    showRazorpay = false
                    Task { await placeOrder(paymentId: pid) }
                },
                onCancel: { showRazorpay = false }
            )
        }
        .sheet(item: $editingAddress) { addr in
            AddressEditSheet(
                address: addr,
                onSave: { saved in
                    addressBook.upsert(saved)
                    addressBook.select(saved.id)
                    applySelectedAddress()
                    editingAddress = nil
                },
                onCancel: { editingAddress = nil }
            )
            .presentationDetents([.large])
        }
        .onAppear { applySelectedAddress() }
        .animation(.easeInOut(duration: 0.25), value: step)
        .animation(.spring(response: 0.4), value: confirmation)
    }

    // MARK: - Step Indicator

    private var stepTitle: String {
        switch step {
        case .address: return "Delivery"
        case .payment: return "Payment"
        case .review:  return "Review & Pay"
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(CheckoutStep.allCases, id: \.rawValue) { s in
                HStack(spacing: 0) {
                    Circle()
                        .fill(s.rawValue <= step.rawValue ? Color.primary : Color(UIColor.systemGray4))
                        .frame(width: 8, height: 8)
                    if s != .review {
                        Rectangle()
                            .fill(s.rawValue < step.rawValue ? Color.primary : Color(UIColor.systemGray4))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(UIColor.systemBackground))
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Step 1: Address + Delivery

    private var addressStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !addressBook.addresses.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Saved Addresses")
                            .font(.footnote).fontWeight(.semibold).foregroundColor(.secondary)
                        Spacer()
                        Button("Add New") {
                            editingAddress = Address(label: "Home", fullName: fullName, phone: phone, line1: "", line2: "", city: "", state: "", zip: "")
                        }
                        .font(.footnote).fontWeight(.semibold)
                    }
                    ForEach(addressBook.addresses) { addr in
                        Button {
                            addressBook.select(addr.id)
                            applySelectedAddress()
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: addressBook.selectedAddressId == addr.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(addressBook.selectedAddressId == addr.id ? .accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(addr.label).font(.subheadline).fontWeight(.semibold)
                                    Text(addr.oneLine).font(.footnote).foregroundColor(.secondary)
                                }
                                Spacer()
                                Button { editingAddress = addr } label: {
                                    Image(systemName: "pencil").foregroundColor(.secondary)
                                }.buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(Color(UIColor.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Guest / manual fields
            VStack(alignment: .leading, spacing: 4) {
                if AuthSession.shared.currentUser == nil {
                    HStack {
                        Spacer()
                        Button("Sign in to autofill") {
                            NotificationCenter.default.post(name: .requireAuth, object: nil)
                        }
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                    }
                    .padding(.bottom, 4)
                }

                formCard {
                    Group {
                        LabeledTextField("Full Name", text: $fullName, contentType: .name)
                        Divider().padding(.leading, 14)
                        LabeledTextField("Phone", text: $phone, keyboardType: .phonePad)
                        Divider().padding(.leading, 14)
                        LabeledTextField("Email", text: $email, contentType: .emailAddress, keyboardType: .emailAddress)
                    }
                }

                formCard {
                    Group {
                        LabeledTextField("Address Line 1", text: $address1, contentType: .streetAddressLine1)
                        Divider().padding(.leading, 14)
                        LabeledTextField("Address Line 2 (optional)", text: $address2)
                        Divider().padding(.leading, 14)
                        HStack(spacing: 0) {
                            TextField("City", text: $city)
                                .padding(14).font(.subheadline)
                            Divider().frame(height: 44)
                            TextField("State", text: $state)
                                .padding(14).font(.subheadline)
                            Divider().frame(height: 44)
                            TextField("PIN", text: $zip).keyboardType(.numberPad)
                                .padding(14).font(.subheadline)
                        }
                    }
                }
            }

            // Delivery speed (shown always, consistent with spec)
            VStack(alignment: .leading, spacing: 10) {
                Text("Delivery Speed")
                    .font(.footnote).fontWeight(.semibold).foregroundColor(.secondary)

                ForEach(ShippingSpeed.allCases) { speed in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { shippingSpeed = speed }
                    } label: {
                        HStack {
                            Image(systemName: shippingSpeed == speed ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(shippingSpeed == speed ? .primary : .secondary)
                            Text(speed.rawValue)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(14)
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(shippingSpeed == speed ? Color.primary : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Step 2: Payment

    private var paymentStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            orderSummaryCard

            VStack(alignment: .leading, spacing: 10) {
                Text("Payment Method")
                    .font(.footnote).fontWeight(.semibold).foregroundColor(.secondary)

                ForEach(PaymentMethod.allCases) { method in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { paymentMethod = method }
                    } label: {
                        HStack {
                            Image(systemName: paymentMethod == method ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(paymentMethod == method ? .primary : .secondary)
                            Text(method.rawValue).font(.subheadline)
                            Spacer()
                        }
                        .padding(14)
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(paymentMethod == method ? Color.primary : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if paymentMethod == .razorpay && Config.razorpayKey == "rzp_test_YOUR_KEY_HERE" {
                    Text("Razorpay key missing in Config.swift. Use Mock Pay for demo.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            // Applied promo (read-only)
            if let code = cartManager.appliedPromoCode {
                HStack(spacing: 8) {
                    Image(systemName: "tag.fill").foregroundColor(.green).font(.subheadline)
                    Text("\(code) applied").font(.subheadline).foregroundColor(.green)
                    Spacer()
                    NavigationLink("Change in cart") {
                        EmptyView()
                    }
                    .font(.caption).foregroundColor(.secondary)
                    .simultaneousGesture(TapGesture().onEnded { dismiss() })
                }
                .padding(14)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let err = errorMessage {
                Text(err).font(.caption).foregroundColor(.red)
                    .padding(12)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    // MARK: - Step 3: Review & Pay

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Items
            VStack(alignment: .leading, spacing: 0) {
                Text("Items").font(.footnote).fontWeight(.semibold).foregroundColor(.secondary)
                    .padding(.bottom, 8)
                ForEach(checkoutItems) { item in
                    HStack(spacing: 10) {
                        if let url = item.product.imageUrl {
                            CachedImageView(urlString: url) { img in img.resizable().scaledToFill() }
                                placeholder: { Color(.systemGray5) }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.product.name).font(.subheadline).lineLimit(1)
                            Text("Qty \(item.quantity)").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(fmt(item.product.price * Double(item.quantity))).font(.subheadline)
                    }
                    .padding(.vertical, 8)
                    if item.id != checkoutItems.last?.id { Divider() }
                }
            }
            .padding(14)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Delivery address
            VStack(alignment: .leading, spacing: 6) {
                Text("Delivering to").font(.footnote).fontWeight(.semibold).foregroundColor(.secondary)
                Text("\(fullName)").font(.subheadline).fontWeight(.medium)
                Text("\(address1)\(address2.isEmpty ? "" : ", \(address2)")\n\(city), \(state) \(zip)")
                    .font(.subheadline).foregroundColor(.secondary)
                Text(shippingSpeed.rawValue).font(.caption).foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Payment method
            VStack(alignment: .leading, spacing: 4) {
                Text("Payment").font(.footnote).fontWeight(.semibold).foregroundColor(.secondary)
                Text(paymentMethod.rawValue).font(.subheadline)
            }
            .padding(14)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            orderSummaryCard

            if let err = errorMessage {
                Text(err).font(.caption).foregroundColor(.red)
                    .padding(12)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    // MARK: - Order Summary Card

    private var orderSummaryCard: some View {
        VStack(spacing: 0) {
            summaryRow("Subtotal", fmt(itemsSubtotal))
            if discount > 0, let code = cartManager.appliedPromoCode {
                Divider().padding(.horizontal, 14)
                summaryRow("Promo (\(code))", "−\(fmt(discount))", color: .green)
            }
            Divider().padding(.horizontal, 14)
            summaryRow("Shipping", shippingSpeed.fee == 0 ? "Free" : fmt(shippingSpeed.fee),
                       color: shippingSpeed.fee == 0 ? .green : .primary)
            Divider().padding(.horizontal, 14)
            HStack {
                Text("Total").font(.subheadline).fontWeight(.bold)
                Spacer()
                Text(fmt(grandTotal)).font(.subheadline).fontWeight(.bold)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func summaryRow(_ label: String, _ value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline).foregroundColor(color)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: - CTA Bar

    private var ctaBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                handleCTA()
            } label: {
                Group {
                    if isPlacing {
                        ProgressView().tint(.white)
                    } else {
                        Text(step == .review
                             ? "Place Order · \(fmt(grandTotal))"
                             : step == .address ? "Continue to Payment" : "Review Order")
                            .font(.subheadline).fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background((step == .address && !addressValid) || isPlacing
                             ? Color.secondary.opacity(0.4) : Color.primary)
                .foregroundColor(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled((step == .address && !addressValid) || isPlacing)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Confirmation View

    private func confirmationView(_ c: Confirmation) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 96, height: 96)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.green)
                }
                Text("Order Placed!").font(.title2).fontWeight(.bold)
                Text("Order ID: \(c.orderId)").font(.footnote).foregroundColor(.secondary)
                Text("You'll receive a confirmation soon.")
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Text("Track Order")
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.primary)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        NotificationCenter.default.post(name: .goToShopTab, object: nil)
                    }
                } label: {
                    Text("Continue Shopping")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Helpers

    private func handleCTA() {
        withAnimation(.easeInOut(duration: 0.25)) {
            switch step {
            case .address: step = .payment
            case .payment: step = .review
            case .review:
                Task {
                    errorMessage = nil
                    if paymentMethod == .razorpay {
                        if Config.razorpayKey == "rzp_test_YOUR_KEY_HERE" {
                            errorMessage = "Razorpay key missing. Use Mock Pay."
                            return
                        }
                        showRazorpay = true
                    } else {
                        await placeOrder(paymentId: "mock_\(UUID().uuidString.prefix(8))")
                    }
                }
            }
        }
    }

    private func applySelectedAddress() {
        guard let addr = addressBook.selectedAddress else { return }
        if !addr.fullName.isEmpty { fullName = addr.fullName }
        if !addr.phone.isEmpty { phone = addr.phone }
        if !addr.line1.isEmpty { address1 = addr.line1 }
        if !addr.line2.isEmpty { address2 = addr.line2 }
        if !addr.city.isEmpty { city = addr.city }
        if !addr.state.isEmpty { state = addr.state }
        if !addr.zip.isEmpty { zip = addr.zip }
    }

    private func placeOrder(paymentId: String) async {
        guard let userId = AuthSession.shared.currentUser?.id else {
            errorMessage = "Please log in to place an order."
            return
        }
        isPlacing = true
        defer { isPlacing = false }

        let summary   = checkoutItems.map { "\($0.product.name) x\($0.quantity)" }.joined(separator: ", ")
        let imageUrl  = checkoutItems.first?.product.imageUrl ?? ""
        let cartPayload = checkoutItems.map { ["product_id": $0.product.id, "quantity": $0.quantity] }

        guard let url = URL(string: "\(APIService.baseURL)/orders") else {
            errorMessage = "Invalid backend URL."; return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "user_id": userId, "total": grandTotal,
            "items_summary": summary, "image_url": imageUrl,
            "payment_id": paymentId, "cart_items": cartPayload
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                errorMessage = msg ?? "Order failed."; return
            }
            let obj   = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let order = obj["order"] as? [String: Any]
            let orderId = (order?["id"] as? String) ?? UUID().uuidString
            await MainActor.run {
                OrderManager.shared.addOrder(from: checkoutItems, total: grandTotal, paymentId: paymentId)
                for item in checkoutItems { cartManager.removeLineItem(product: item.product) }
                cartManager.removePromo()
                withAnimation { confirmation = Confirmation(orderId: orderId, total: grandTotal, paymentId: paymentId) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Form Helpers

private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 0) { content() }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.top, 10)
}

private struct LabeledTextField: View {
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default

    init(_ placeholder: String, text: Binding<String>,
         contentType: UITextContentType? = nil,
         keyboardType: UIKeyboardType = .default) {
        self.placeholder = placeholder
        self._text = text
        self.contentType = contentType
        self.keyboardType = keyboardType
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.subheadline)
            .keyboardType(keyboardType)
            .textContentType(contentType)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
    }
}

// MARK: - Razorpay Capture View

private struct RazorpayPaymentCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    let amount: Double
    let onSuccess: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            RazorpayWebView(
                amount: amount,
                razorpayKey: Config.razorpayKey,
                onPaymentSuccess: { pid in onSuccess(pid) },
                onPaymentError: { _ in onCancel() }
            )
            .navigationTitle("Razorpay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss(); onCancel() }
                }
            }
        }
    }
}

// MARK: - Address Edit Sheet

private struct AddressEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var address: Address
    let onSave: (Address) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") { TextField("Home / Work", text: $address.label) }
                Section("Contact") {
                    TextField("Full name", text: $address.fullName)
                    TextField("Phone", text: $address.phone).keyboardType(.phonePad)
                }
                Section("Address") {
                    TextField("Line 1", text: $address.line1)
                    TextField("Line 2", text: $address.line2)
                    TextField("City", text: $address.city)
                    TextField("State", text: $address.state)
                    TextField("ZIP", text: $address.zip).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss(); onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { dismiss(); onSave(address) }.fontWeight(.semibold)
                }
            }
        }
    }
}
