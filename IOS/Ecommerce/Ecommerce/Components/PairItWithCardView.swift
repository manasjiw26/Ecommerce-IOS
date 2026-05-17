import SwiftUI

struct PairItWithCardView: View {
    let recommendation: PairItWithProduct
    @EnvironmentObject private var cartManager: CartManager
    @State private var addedToCart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Product Image + Add Button
            ZStack(alignment: .bottomTrailing) {
                if let imageUrlString = recommendation.product.imageUrl {
                    CachedImageView(urlString: imageUrlString) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 146, height: 146)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 146, height: 146)
                            .shimmer()
                    }
                    .id(imageUrlString)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 146, height: 146)
                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                }

                if recommendation.product.stock == 0 {
                    Color.black.opacity(0.4)
                        .overlay(
                            Text("OUT OF STOCK")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        )
                }

                // Add to Cart button
                Button {
                    guard recommendation.product.stock ?? 0 > 0 else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        cartManager.addToCart(product: recommendation.product)
                        addedToCart = true
                    }
                    // Reset checkmark after 1.5s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { addedToCart = false }
                    }
                } label: {
                    Image(systemName: addedToCart ? "checkmark" : (recommendation.product.stock == 0 ? "xmark" : "plus"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(addedToCart ? Color.green : (recommendation.product.stock == 0 ? Color.gray.opacity(0.4) : Color.black.opacity(0.75)))
                        .clipShape(Circle())
                }
                .padding(8)
                .buttonStyle(PlainButtonStyle())
                .disabled(recommendation.product.stock == 0)
            }
            .frame(width: 146, height: 146)

            // Product Info with interior padding
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.product.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .topLeading)

                Text("$\(String(format: "%.2f", recommendation.product.price))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(10)
        }
        .frame(width: 146)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 3)
    }
}
