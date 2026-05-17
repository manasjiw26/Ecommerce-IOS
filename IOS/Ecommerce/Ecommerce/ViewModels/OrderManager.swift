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
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = "Order #\(intId)"
        } else if let strId = try? container.decode(String.self, forKey: .id) {
            id = strId
        } else {
            id = UUID().uuidString
        }
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



    func clearAll() {
        orders = []
    }
}
