import SwiftUI

struct CheckoutSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var cartManager: CartManager

    let checkoutItems: [CartItem]
    let addOnTotal: Double

    @State private var shippingSpeed: ShippingSpeed = .standard
    @State private var paymentMethod: PaymentMethod = .mockPay

    @State private var fullName: String = AuthSession.shared.currentUser?.name ?? ""
    @State private var email: String = AuthSession.shared.currentUser?.email ?? ""
    @State private var phone: String = ""
    @State private var address1: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zip: String = ""

    @State private var isPlacing = false
    @State private var errorMessage: String? = nil
    @State private var confirmation: Confirmation? = nil

    @State private var showRazorpay = false
    @State private var razorpayPaymentId: String? = nil

    enum ShippingSpeed: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case express = "Express"
        case overnight = "Overnight"
        var id: String { rawValue }

        var fee: Double {
            switch self {
            case .standard: return 0
            case .express: return 14.99
            case .overnight: return 29.99
            }
        }
    }

    enum PaymentMethod: String, CaseIterable, Identifiable {
        case razorpay = "Razorpay"
        case mockPay = "Mock Pay"
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

    private var grandTotal: Double {
        itemsSubtotal + addOnTotal + shippingSpeed.fee
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 18) {
                        reviewSection
                        deliverySection
                        paymentSection
                        finalizeSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }

                if let confirmation {
                    CheckoutConfirmationOverlay(confirmation: confirmation) {
                        dismiss()
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $showRazorpay) {
            RazorpayPaymentCaptureView(
                amount: grandTotal,
                onSuccess: { pid in
                    razorpayPaymentId = pid
                    showRazorpay = false
                    Task { await placeOrder(paymentId: pid) }
                },
                onCancel: {
                    showRazorpay = false
                }
            )
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review")
                .font(.headline)

            ForEach(checkoutItems) { item in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(item.quantity)x")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 28, alignment: .leading)
                    Text(item.product.name)
                        .font(.subheadline)
                        .lineLimit(2)
                    Spacer()
                    Text("$\(String(format: "%.2f", item.product.price * Double(item.quantity)))")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }

            Divider().padding(.vertical, 4)

            HStack {
                Text("Items")
                Spacer()
                Text("$\(String(format: "%.2f", itemsSubtotal))")
            }
            .font(.subheadline)

            if addOnTotal > 0 {
                HStack {
                    Text("Add-ons")
                    Spacer()
                    Text("$\(String(format: "%.2f", addOnTotal))")
                }
                .font(.subheadline)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var deliverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Delivery")
                .font(.headline)

            VStack(spacing: 10) {
                TextField("Full name", text: $fullName)
                    .textContentType(.name)
                    .textFieldStyle(.roundedBorder)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
                    .textFieldStyle(.roundedBorder)
                TextField("Address line 1", text: $address1)
                    .textContentType(.streetAddressLine1)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 10) {
                    TextField("City", text: $city).textFieldStyle(.roundedBorder)
                    TextField("State", text: $state).textFieldStyle(.roundedBorder)
                }
                TextField("ZIP", text: $zip)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }

            Picker("Shipping speed", selection: $shippingSpeed) {
                ForEach(ShippingSpeed.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Shipping")
                Spacer()
                Text(shippingSpeed.fee == 0 ? "Free" : "$\(String(format: "%.2f", shippingSpeed.fee))")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Payment")
                .font(.headline)

            Picker("Method", selection: $paymentMethod) {
                ForEach(PaymentMethod.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            if paymentMethod == .razorpay && Config.razorpayKey == "rzp_test_YOUR_KEY_HERE" {
                Text("Razorpay key missing in Config.swift. Use Mock Pay or add your key.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var finalizeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Order")
                .font(.headline)

            HStack {
                Text("Total")
                Spacer()
                Text("$\(String(format: "%.2f", grandTotal))")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)

            Button {
                Task {
                    errorMessage = nil
                    if paymentMethod == .razorpay {
                        if Config.razorpayKey == "rzp_test_YOUR_KEY_HERE" {
                            errorMessage = "Razorpay key missing. Add it or use Mock Pay."
                            return
                        }
                        showRazorpay = true
                    } else {
                        await placeOrder(paymentId: "mock_\(UUID().uuidString.prefix(8))")
                    }
                }
            } label: {
                if isPlacing {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text("Place Order ($\(String(format: "%.2f", grandTotal)))")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .disabled(isPlacing || !canPlaceOrder)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var canPlaceOrder: Bool {
        !checkoutItems.isEmpty &&
        !address1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !zip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func placeOrder(paymentId: String) async {
        guard let userId = AuthSession.shared.currentUser?.id else {
            errorMessage = "Please log in to place an order."
            return
        }

        isPlacing = true
        defer { isPlacing = false }

        let summary = checkoutItems.map { "\($0.product.name) x\($0.quantity)" }.joined(separator: ", ")
        let imageUrl = checkoutItems.first?.product.imageUrl ?? ""
        let cartPayload = checkoutItems.map { ["product_id": $0.product.id, "quantity": $0.quantity] }

        guard let url = URL(string: "\(APIService.baseURL)/orders") else {
            errorMessage = "Invalid backend URL."
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "user_id": userId,
            "total": grandTotal,
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
                errorMessage = msg ?? "Order failed."
                return
            }

            let obj = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let order = obj["order"] as? [String: Any]
            let orderId = (order?["id"] as? String) ?? UUID().uuidString

            await MainActor.run {
                confirmation = Confirmation(orderId: orderId, total: grandTotal, paymentId: paymentId)
                // Remove only checked-out items from local bag.
                for item in checkoutItems {
                    cartManager.removeLineItem(product: item.product)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CheckoutConfirmationOverlay: View {
    let confirmation: CheckoutSheetView.Confirmation
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("Order placed")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Order ID: \(confirmation.orderId)")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("Payment: \(confirmation.paymentId)")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .padding(.top, 10)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

// Captures a payment id via Razorpay's web checkout, without placing orders itself.
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
                    Button("Close") {
                        dismiss()
                        onCancel()
                    }
                }
            }
        }
    }
}

