import SwiftUI

// Cart-tab checkout flow (native iOS, multi-step, no hard dependency on Razorpay).
// Uses backend POST /orders to place the order and clears backend cart on success.

struct CheckoutFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var cartManager: CartManager

    @State private var path: [Route] = []
    let checkoutItems: [CartItem]

    // Shipping / delivery
    @State private var fullName: String = AuthSession.shared.currentUser?.name ?? ""
    @State private var phone: String = ""
    @State private var addressLine1: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zip: String = ""
    @State private var delivery: DeliveryOption = .standard

    // Payment
    @State private var paymentMethod: PaymentMethod = .mock

    // Order placement
    @State private var isPlacingOrder = false
    @State private var placeOrderError: String? = nil
    @State private var confirmationOrderId: String? = nil

    enum Route: Hashable {
        case details
        case payment
        case confirmation
    }

    enum DeliveryOption: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case express = "Express"
        var id: String { rawValue }
    }

    enum PaymentMethod: String, CaseIterable, Identifiable {
        case mock = "Mock Pay"
        case razorpay = "Razorpay"
        var id: String { rawValue }
    }

    init(checkoutItems: [CartItem] = []) {
        self.checkoutItems = checkoutItems
    }

    private var effectiveItems: [CartItem] {
        checkoutItems.isEmpty ? cartManager.items : checkoutItems
    }

    private var effectiveTotal: Double {
        effectiveItems.reduce(0) { $0 + ($1.product.price * Double($1.quantity)) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            CheckoutReviewStep(
                items: effectiveItems,
                total: effectiveTotal,
                onContinue: { path.append(.details) }
            )
            .environmentObject(cartManager)
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .details:
                    CheckoutDetailsStep(
                        fullName: $fullName,
                        phone: $phone,
                        addressLine1: $addressLine1,
                        city: $city,
                        state: $state,
                        zip: $zip,
                        delivery: $delivery,
                        onContinue: { path.append(.payment) }
                    )
                    .navigationTitle("Delivery")
                    .navigationBarTitleDisplayMode(.inline)

                case .payment:
                    CheckoutPaymentStep(
                        paymentMethod: $paymentMethod,
                        total: effectiveTotal,
                        isPlacingOrder: isPlacingOrder,
                        errorMessage: placeOrderError,
                        onPlaceOrder: { Task { await placeOrder() } }
                    )
                    .navigationTitle("Payment")
                    .navigationBarTitleDisplayMode(.inline)

                case .confirmation:
                    CheckoutConfirmationStep(orderId: confirmationOrderId ?? "")
                        .navigationBarBackButtonHidden(true)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { dismiss() }
                            }
                        }
                }
            }
        }
    }

    private func placeOrder() async {
        placeOrderError = nil
        guard !effectiveItems.isEmpty else {
            placeOrderError = "Your cart is empty."
            return
        }
        guard let userId = AuthSession.shared.currentUser?.id else {
            placeOrderError = "Please log in to place an order."
            return
        }

        isPlacingOrder = true
        defer { isPlacingOrder = false }

        let paymentId: String = {
            switch paymentMethod {
            case .mock: return "mock_\(UUID().uuidString.prefix(8))"
            case .razorpay: return "razorpay_pending"
            }
        }()

        let summary = effectiveItems.map { "\($0.product.name) x\($0.quantity)" }.joined(separator: ", ")
        let imageUrl = effectiveItems.first?.product.imageUrl ?? ""
        let cartPayload = effectiveItems.map { ["product_id": $0.product.id, "quantity": $0.quantity] }

        guard let url = URL(string: "\(APIService.baseURL)/orders") else {
            placeOrderError = "Invalid backend URL."
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_id": userId,
            "total": effectiveTotal,
            "items_summary": summary,
            "image_url": imageUrl,
            "payment_id": paymentId,
            "cart_items": cartPayload
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                placeOrderError = msg ?? "Order failed."
                return
            }

            // Parse response: { message, order: { id, ... } }
            let obj = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let order = obj["order"] as? [String: Any]
            let orderId = (order?["id"] as? String) ?? UUID().uuidString
            confirmationOrderId = orderId

            // Update local orders list (Orders tab) and clear cart (local + backend will clear too).
            await MainActor.run {
                // If we're doing selective checkout, remove only the checked out line items.
                if checkoutItems.isEmpty {
                    cartManager.removeAll()
                } else {
                    for item in checkoutItems {
                        cartManager.removeLineItem(product: item.product)
                    }
                }
            }
            await OrderManager.shared.fetchOrders()

            path.append(.confirmation)
        } catch {
            placeOrderError = error.localizedDescription
        }
    }
}

private struct CheckoutReviewStep: View {
    let items: [CartItem]
    let total: Double
    let onContinue: () -> Void

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        if let url = item.product.imageUrl {
                            CachedImageView(urlString: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color(.systemGray5)
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.product.name)
                                .font(.subheadline)
                                .lineLimit(2)
                            Text("Qty \(item.quantity)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("$\(String(format: "%.2f", item.product.price * Double(item.quantity)))")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            } header: {
                Text("Items")
            }

            Section {
                HStack {
                    Text("Subtotal")
                    Spacer()
                    Text("$\(String(format: "%.2f", total))")
                }
                HStack {
                    Text("Shipping")
                    Spacer()
                    Text("Calculated next")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Tax")
                    Spacer()
                    Text("Estimated")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Summary")
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button(action: onContinue) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}

private struct CheckoutDetailsStep: View {
    @Binding var fullName: String
    @Binding var phone: String
    @Binding var addressLine1: String
    @Binding var city: String
    @Binding var state: String
    @Binding var zip: String
    @Binding var delivery: CheckoutFlowView.DeliveryOption
    let onContinue: () -> Void

    var body: some View {
        Form {
            Section("Contact") {
                TextField("Full name", text: $fullName)
                    .textContentType(.name)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
            }

            Section("Address") {
                TextField("Address line 1", text: $addressLine1)
                    .textContentType(.streetAddressLine1)
                TextField("City", text: $city)
                TextField("State", text: $state)
                TextField("ZIP", text: $zip)
                    .keyboardType(.numberPad)
            }

            Section("Delivery") {
                Picker("Option", selection: $delivery) {
                    ForEach(CheckoutFlowView.DeliveryOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button(action: onContinue) {
                    Text("Continue to Payment")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .disabled(addressLine1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || city.isEmpty || zip.isEmpty)
            }
            .padding()
            .background(.black)
        }
    }
}

private struct CheckoutPaymentStep: View {
    @Binding var paymentMethod: CheckoutFlowView.PaymentMethod
    let total: Double
    let isPlacingOrder: Bool
    let errorMessage: String?
    let onPlaceOrder: () -> Void

    var body: some View {
        List {
            Section("Payment Method") {
                Picker("Method", selection: $paymentMethod) {
                    ForEach(CheckoutFlowView.PaymentMethod.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.inline)

                if paymentMethod == .razorpay {
                    Text("Razorpay requires keys. Use Mock Pay for local demo.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Total") {
                HStack {
                    Text("Amount")
                    Spacer()
                    Text("$\(String(format: "%.2f", total))")
                        .fontWeight(.semibold)
                }
            }

            if let errorMessage, !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button(action: onPlaceOrder) {
                    if isPlacingOrder {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Place Order")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPlacingOrder)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}

private struct CheckoutConfirmationStep: View {
    let orderId: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)
                .padding(.top, 24)
            Text("Order placed")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Order ID: \(orderId)")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
}
