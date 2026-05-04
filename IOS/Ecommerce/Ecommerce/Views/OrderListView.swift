import SwiftUI

enum OrderStatus: String, CaseIterable {
    case processing = "Processing"
    case shipped = "Shipped"
    case delivered = "Delivered"
    
    var color: Color {
        switch self {
        case .processing: return .orange
        case .shipped: return .blue
        case .delivered: return .green
        }
    }
    
    var stepIndex: Int {
        switch self {
        case .processing: return 0
        case .shipped: return 1
        case .delivered: return 2
        }
    }
}

struct Order: Identifiable {
    let id: String
    let date: Date
    let total: Double
    let status: OrderStatus
    let itemsSummary: String
    let imageUrlString: String
}

struct OrderListView: View {
    @ObservedObject private var orderManager = OrderManager.shared
    
    private func toOrder(_ p: PlacedOrder) -> Order {
        let status: OrderStatus
        switch p.status {
        case "Shipped": status = .shipped
        case "Delivered": status = .delivered
        default: status = .processing
        }
        return Order(id: p.id, date: p.date, total: p.total, status: status,
                     itemsSummary: p.itemsSummary, imageUrlString: p.imageUrlString)
    }
    
    var body: some View {
        Group {
            if orderManager.orders.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "shippingbox")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No orders yet")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("When you place an order, its tracking status will appear here.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemGroupedBackground))
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(orderManager.orders) { placed in
                            NavigationLink(destination: OrderDetailView(order: placed)) {
                                OrderCardView(order: toOrder(placed))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
    }
}

struct OrderCardView: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.id)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(order.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text("$\(String(format: "%.2f", order.total))")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            Divider()
            
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(order.itemsSummary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        
                    Spacer()
                }
                
                Spacer()
                
                CachedImageView(urlString: order.imageUrlString) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                }
                .id(order.imageUrlString)
            }
            
            OrderProgressView(status: order.status)
                .padding(.top, 8)
            
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

struct OrderProgressView: View {
    let status: OrderStatus
    let steps = ["Processing", "Shipped", "Delivered"]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Status: \(status.rawValue)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(status.color)
                Spacer()
            }
            
            HStack(spacing: 0) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= status.stepIndex ? status.color : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < status.stepIndex ? status.color : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            
            HStack {
                Text(steps[0]).font(.system(size: 10)).fontWeight(0 <= status.stepIndex ? .bold : .regular).foregroundColor(0 <= status.stepIndex ? .primary : .gray)
                Spacer()
                Text(steps[1]).font(.system(size: 10)).fontWeight(1 <= status.stepIndex ? .bold : .regular).foregroundColor(1 <= status.stepIndex ? .primary : .gray)
                Spacer()
                Text(steps[2]).font(.system(size: 10)).fontWeight(2 <= status.stepIndex ? .bold : .regular).foregroundColor(2 <= status.stepIndex ? .primary : .gray)
            }
        }
    }
}

struct OrderListView_Previews: PreviewProvider {
    static var previews: some View {
        OrderListView()
    }
}
