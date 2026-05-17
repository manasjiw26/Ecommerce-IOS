import SwiftUI
import Combine

struct AIRecommendationCard: View {
    let product: Product
    var showAIPickBadge: Bool = true
    @State private var appeared = false
    
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
                
                if showAIPickBadge {
                    AISparkBadge(label: "AI Pick", size: .small)
                        .padding(8)
                }
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
                    TypewriterText(fullText: reasoning, messageId: UUID())
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
