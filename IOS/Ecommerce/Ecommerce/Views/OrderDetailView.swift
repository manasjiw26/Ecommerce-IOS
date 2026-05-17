import SwiftUI

struct OrderDetailView: View {
    let order: PlacedOrder
    @State private var stepsRevealed = 0
    
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
                        ForEach(Array(["Order Placed", "Processing", "Shipped", "Delivered"].enumerated()), id: \.offset) { i, title in
                            let subtitle: String = {
                                switch i {
                                case 0: return order.date.formatted(date: .abbreviated, time: .shortened)
                                case 1: return "Your order is being prepared"
                                case 2: return (order.status == "Shipped" || order.status == "Delivered") ? "On the way" : "Pending"
                                case 3: return order.status == "Delivered" ? "Package delivered" : "Pending"
                                default: return ""
                                }
                            }()
                            let isCompleted: Bool = {
                                switch i {
                                case 0, 1: return true
                                case 2: return order.status == "Shipped" || order.status == "Delivered"
                                case 3: return order.status == "Delivered"
                                default: return false
                                }
                            }()
                            
                            OrderStep(title: title, subtitle: subtitle, isCompleted: isCompleted, isLast: i == 3)
                                .opacity(stepsRevealed > i ? 1 : 0)
                                .offset(x: stepsRevealed > i ? 0 : -20)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(i) * 0.15), value: stepsRevealed)
                        }
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
        .toolbar(.visible, for: .tabBar)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                stepsRevealed = 4
            }
        }
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
