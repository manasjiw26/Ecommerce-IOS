import SwiftUI

struct RecommendationCarouselView: View {
    let recommendedProducts: [Product]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
//                Image(systemName: "sparkles")
//                    .font(.subheadline)
//                    .foregroundColor(.primary)
                Text("Picked For You")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(recommendedProducts) { product in
                        NavigationLink(destination: ProductDetailView(product: product)) {
                            AIRecommendationCard(product: product)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
        .padding(.bottom, 8)
        
        Divider()
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }
}
