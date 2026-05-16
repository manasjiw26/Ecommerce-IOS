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
                            .frame(width: 140, height: 140)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 140, height: 140)
                            .shimmer()
                    }
                    .id(imageUrlString)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 140, height: 140)
                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                }

                // Add to Cart button — triggers reactive recommendation refresh
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        cartManager.addToCart(product: recommendation.product)
                        addedToCart = true
                    }
                    // Reset checkmark after 1.5s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { addedToCart = false }
                    }
                } label: {
                    Image(systemName: addedToCart ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(addedToCart ? Color.green : Color.black.opacity(0.75))
                        .clipShape(Circle())
                }
                .padding(8)
                .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Product Info
            VStack(alignment: .leading, spacing: 3) {
                Text(recommendation.product.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("$\(String(format: "%.2f", recommendation.product.price))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                // AI-generated reasoning — only shown when backend provides it
                if let reasoning = recommendation.aiReasoning {
                    Text(reasoning)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .italic()
                        .lineLimit(2)
                        .padding(.top, 1)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 2)
        }
        .frame(width: 140)
    }
}
