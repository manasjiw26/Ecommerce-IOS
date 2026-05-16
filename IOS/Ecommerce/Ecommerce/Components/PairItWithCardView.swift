import SwiftUI

struct PairItWithCardView: View {
    let recommendation: PairItWithProduct
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image with Recommendation Label
            ZStack(alignment: .topLeading) {
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
                
                // Removed recommendation label as per request
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.product.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("$\(String(format: "%.2f", recommendation.product.price))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            .padding(.horizontal, 2)
        }
        .frame(width: 140)
    }
}
