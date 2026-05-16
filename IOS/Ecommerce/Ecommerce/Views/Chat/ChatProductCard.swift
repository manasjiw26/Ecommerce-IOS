import SwiftUI

struct ChatProductCard: View {
    let product: Product
    let viewModel: ChatViewModel
    @EnvironmentObject var cartManager: CartManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            if let url = product.imageUrl {
                CachedImageView(urlString: url) { img in
                    img.resizable()
                       .scaledToFill()
                       .frame(width: 130, height: 110)
                       .clipped()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                        .frame(width: 130, height: 110)
                        .shimmer()
                }
            } else {
                 Rectangle().fill(Color(.systemGray5))
                    .frame(width: 130, height: 110)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .frame(width: 110, alignment: .leading)

                Text(String(format: "$%.2f", product.price))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let reasoning = product.aiReasoning {
                    Text(reasoning)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                        .lineLimit(2)
                        .frame(width: 110, alignment: .leading)
                }

                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    cartManager.addToCart(product: product)
                    RecommendationEngine.shared.logEvent(productId: product.id, eventType: "add_to_cart")
                }) {
                    Text("Add to cart")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            .padding(10)
        }
        .frame(width: 130)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 0.5))
        .onTapGesture {
            viewModel.context.lastViewedProductId = product.id
            RecommendationEngine.shared.logEvent(productId: product.id, eventType: "view")
        }
    }
}
