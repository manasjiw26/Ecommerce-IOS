import SwiftUI
import Combine

struct AIRecommendationCard: View {
    let product: Product
    var showAIPickBadge: Bool = true
    @State private var appeared = false

    // Fixed dimensions — every card in the HStack must be identical in size
    private let cardWidth: CGFloat  = 150
    private let imageHeight: CGFloat = 150
    private let textAreaHeight: CGFloat = 64   // enough for 2-line name + price

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Image ──────────────────────────────────────────────────────
            ZStack {
                if let imageUrlString = product.imageUrl {
                    CachedImageView(urlString: imageUrlString) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .shimmer()
                    }
                    .id(imageUrlString)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                }
            }
            .frame(width: cardWidth, height: imageHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // ── Text area — fixed height so cards don't resize ─────────────
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("$\(String(format: "%.2f", product.price))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: cardWidth, height: textAreaHeight, alignment: .topLeading)
            .padding(.top, 8)
        }
        .frame(width: cardWidth)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
        .onDisappear { appeared = false }
    }
}

