import SwiftUI

struct ChatOrderCard: View {
    let order: PlacedOrder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.id)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(order.itemsSummary.prefix(50) + (order.itemsSummary.count > 50 ? "…" : ""))
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "$%.2f", order.total))
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text(order.status)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(order.status == "Delivered" ? .green : .orange)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: 300, alignment: .leading)
    }
}
