import SwiftUI

struct OccasionSuggestionsView: View {
    let occasion: Occasion
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var cartManager: CartManager
    @StateObject var recommendationEngine = RecommendationEngine.shared
    
    private let gridHorizontalPadding: CGFloat = 12
    private let gridColumnSpacing: CGFloat = 16
    
    private func productCardWidth(in geometry: GeometryProxy) -> CGFloat {
        let width = geometry.size.width
        let availableWidth = width - (gridHorizontalPadding * 2) - gridColumnSpacing
        return floor(availableWidth / 2)
    }

    private func productCardHeight(in geometry: GeometryProxy) -> CGFloat {
        productCardWidth(in: geometry) + 86
    }
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // Instead of local filtering, we now use the AI-driven search results from our backend
    var displayProducts: [Product] {
        if recommendationEngine.searchResults.isEmpty {
            // Fallback to local filtering if backend is slow or offline
            return productViewModel.products.filter { $0.tags?.contains(occasion.tag) ?? false }
        } else {
            return recommendationEngine.searchResults
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header Banner
                        ZStack(alignment: .bottomLeading) {
                            if occasion.isLocalAsset, let assetName = occasion.backgroundImageUrl {
                                Image(assetName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 180)
                                    .clipped()
                            } else if let urlString = occasion.backgroundImageUrl {
                                CachedImageView(urlString: urlString) { image in
                                    image.resizable().scaledToFill().frame(height: 180).clipped()
                                } placeholder: {
                                    Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 180)
                                }
                            }
                            
                            LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.7)]), startPoint: .top, endPoint: .bottom)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(occasion.title)
                                    .font(.system(size: 10, weight: .bold))
                                    .kerning(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                                
                                Text(occasion.subtitle)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text(occasion.description)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(20)
                        }
                        .frame(height: 180)
                        
                        Text("AI-Recommended for you")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                            .padding(.bottom, 16)
                        
                        if displayProducts.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("No suggestions available for this occasion yet.")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 300)
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(displayProducts) { product in
                                    NavigationLink(destination: ProductDetailView(product: product)) {
                                        ProductCardView(
                                            product: product,
                                            width: productCardWidth(in: geometry),
                                            height: productCardHeight(in: geometry)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, gridHorizontalPadding)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .navigationTitle(occasion.subtitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Ensure search results are triggered if they haven't been already
            if recommendationEngine.searchResults.isEmpty {
                recommendationEngine.searchProducts(query: occasion.tag)
            }
        }
    }
}
