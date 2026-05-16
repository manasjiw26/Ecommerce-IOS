import SwiftUI

struct AIRecommendationCard: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let imageUrlString = product.imageUrl {
                    CachedImageView(urlString: imageUrlString) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 150)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 150, height: 150)
                            .shimmer()
                    }
                    .id(imageUrlString)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 150, height: 150)
                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                }
                
                // AI Badge
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .bold))
                    Text("AI Pick")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.75))
                .clipShape(Capsule())
                .padding(8)
            }
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .frame(width: 150, alignment: .leading)
                
                Text("$\(String(format: "%.2f", product.price))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let reasoning = product.aiReasoning {
                    Text(reasoning)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                        .lineLimit(2)
                        .frame(width: 150, alignment: .leading)
                        .padding(.top, 2)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .frame(width: 150)
    }
}
