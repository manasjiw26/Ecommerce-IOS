import SwiftUI

struct OrderDetailView: View {
    let order: PlacedOrder
    
    var statusColor: Color {
        switch order.status {
        case "Shipped": return .blue
        case "Delivered": return .green
        default: return .orange
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Status Banner
                VStack(spacing: 8) {
                    Image(systemName: order.status == "Delivered" ? "checkmark.circle.fill" : "shippingbox.fill")
                        .font(.system(size: 44))
                        .foregroundColor(statusColor)
                    Text(order.status)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                    Text(order.id)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                
                // Progress Timeline
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tracking")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        OrderStep(title: "Order Placed", subtitle: order.date.formatted(date: .abbreviated, time: .shortened), isCompleted: true, isLast: false)
                        OrderStep(title: "Processing", subtitle: "Your order is being prepared", isCompleted: true, isLast: false)
                        OrderStep(title: "Shipped", subtitle: order.status == "Delivered" || order.status == "Shipped" ? "On the way" : "Pending", isCompleted: order.status == "Shipped" || order.status == "Delivered", isLast: false)
                        OrderStep(title: "Delivered", subtitle: order.status == "Delivered" ? "Package delivered" : "Pending", isCompleted: order.status == "Delivered", isLast: true)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                }
                
                // Order Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Order Summary")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        // Product image + summary
                        HStack(spacing: 14) {
                            CachedImageView(urlString: order.imageUrlString) { image in
                                image.resizable().scaledToFill()
                                    .frame(width: 70, height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 70, height: 70)
                                    .shimmer()
                            }
                            .id(order.imageUrlString)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.itemsSummary)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                            Spacer()
                        }
                        .padding()
                        
                        Divider().padding(.horizontal)
                        
                        HStack {
                            Text("Total Paid")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(String(format: "%.2f", order.total))")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .padding()
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                }
                
                // Payment Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Payment Info")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Payment ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(order.paymentId)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

struct OrderStep: View {
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isCompleted ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(isCompleted ? 1 : 0)
                    )
                if !isLast {
                    Rectangle()
                        .fill(isCompleted ? Color.green.opacity(0.4) : Color.gray.opacity(0.2))
                        .frame(width: 2, height: 36)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isCompleted ? .semibold : .regular)
                    .foregroundColor(isCompleted ? .primary : .secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, -2)
            Spacer()
        }
    }
}
