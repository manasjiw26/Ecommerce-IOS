import Foundation
import Combine

struct PlacedOrder: Identifiable, Codable {
    var id: String
    let date: Date
    let total: Double
    let status: String
    let itemsSummary: String
    let imageUrlString: String
    let paymentId: String

    enum CodingKeys: String, CodingKey {
        case id, total, status
        case date = "created_at"
        case itemsSummary = "items_summary"
        case imageUrlString = "image_url"
        case paymentId = "payment_id"
    }

    // Custom decoder to handle ISO date strings from Supabase
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        total = (try? container.decode(Double.self, forKey: .total)) ?? 0
        status = (try? container.decode(String.self, forKey: .status)) ?? "Processing"
        itemsSummary = (try? container.decode(String.self, forKey: .itemsSummary)) ?? ""
        imageUrlString = (try? container.decode(String.self, forKey: .imageUrlString)) ?? ""
        paymentId = (try? container.decode(String.self, forKey: .paymentId)) ?? ""

        if let dateStr = try? container.decode(String.self, forKey: .date) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = formatter.date(from: dateStr) ?? Date()
        } else {
            date = Date()
        }
    }

    // Local-only init (before server sync)
    init(id: String, date: Date, total: Double, status: String,
         itemsSummary: String, imageUrlString: String, paymentId: String) {
        self.id = id
        self.date = date
        self.total = total
        self.status = status
        self.itemsSummary = itemsSummary
        self.imageUrlString = imageUrlString
        self.paymentId = paymentId
    }
}

class OrderManager: ObservableObject {
    static let shared = OrderManager()

    @Published var orders: [PlacedOrder] = []

    private let baseURL = APIService.baseURL

    // Called immediately after successful Razorpay payment
    func addOrder(from cartItems: [CartItem], total: Double, paymentId: String) {
        let summary = cartItems.map { "\($0.product.name) x\($0.quantity)" }.joined(separator: ", ")
        let imageUrl = cartItems.first?.product.imageUrl ?? ""

        // Show locally first (optimistic)
        let localOrder = PlacedOrder(
            id: "ORD-\(Int.random(in: 10000...99999))",
            date: Date(),
            total: total,
            status: "Processing",
            itemsSummary: summary,
            imageUrlString: imageUrl,
            paymentId: paymentId
        )
        DispatchQueue.main.async { self.orders.insert(localOrder, at: 0) }

        guard let userId = AuthSession.shared.currentUser?.id else { return }

        // Build cart_items payload for stock deduction
        let cartPayload = cartItems.map { ["product_id": $0.product.id, "quantity": $0.quantity] }

        Task {
            await saveOrderToBackend(
                userId: userId, total: total,
                itemsSummary: summary, imageUrl: imageUrl,
                paymentId: paymentId, cartItems: cartPayload
            )
        }
    }

    // Fetch this user's orders from backend
    func fetchOrders() async {
        guard let userId = AuthSession.shared.currentUser?.id,
              let url = URL(string: "\(baseURL)/orders/\(userId)") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let fetched = try JSONDecoder().decode([PlacedOrder].self, from: data)
            await MainActor.run { self.orders = fetched }
        } catch {
            print("OrderManager fetchOrders error: \(error)")
        }
    }

    private func saveOrderToBackend(userId: String, total: Double,
                                    itemsSummary: String, imageUrl: String,
                                    paymentId: String, cartItems: [[String: Any]]) async {
        guard let url = URL(string: "\(baseURL)/orders") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_id": userId,
            "total": total,
            "items_summary": itemsSummary,
            "image_url": imageUrl,
            "payment_id": paymentId,
            "cart_items": cartItems
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            // Re-fetch to get server-assigned id and created_at
            await fetchOrders()
        } catch {
            print("OrderManager saveOrderToBackend error: \(error)")
        }
    }

    func clearAll() {
        orders = []
    }
}
