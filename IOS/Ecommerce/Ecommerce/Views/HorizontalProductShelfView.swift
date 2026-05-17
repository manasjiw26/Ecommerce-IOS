import SwiftUI

struct HorizontalProductShelfView: View {
    let title: String
    let systemImage: String?
    let products: [Product]
    var showAIPickBadge: Bool = false
    
    var body: some View {
        if !products.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    if let icon = systemImage {
                        Image(systemName: icon)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(products) { product in
                            NavigationLink(destination: ProductDetailView(product: product)) {
                                AIRecommendationCard(product: product, showAIPickBadge: showAIPickBadge)
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
}
