import SwiftUI
import UIKit

struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject var cartManager: CartManager
    @ObservedObject private var recoEngine = RecommendationEngine.shared
    private let imageHeight: CGFloat = 320
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                productImage
                
                VStack(alignment: .leading, spacing: 12) {
                    if let category = product.category {
                        Text(category.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(product.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("$\(String(format: "%.2f", product.price))")
                        .font(.title2)
                        .foregroundColor(.primary)
                    
                    if let stock = product.stock {
                        HStack {
                            Circle()
                                .fill(stock > 0 ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(stock > 0 ? "In Stock (\(stock))" : "Out of Stock")
                                .font(.subheadline)
                                .foregroundColor(stock > 0 ? .green : .red)
                        }
                    }
                    
                    Divider()
                    
                    if let description = product.description {
                        Text("Description")
                            .font(.headline)
                        Text(description)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if !recoEngine.recommendedProducts.isEmpty {
                        Divider()
                            .padding(.vertical, 10)
                        
                        Text("Recommended for You")
                            .font(.headline)
                            
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(recoEngine.recommendedProducts) { recProduct in
                                    if recProduct.id != product.id {
                                        NavigationLink(destination: ProductDetailView(product: recProduct)) {
                                            VStack(alignment: .leading) {
                                                if let imageUrlString = recProduct.imageUrl {
                                                    CachedImageView(urlString: imageUrlString) { image in
                                                        image.resizable().scaledToFill().frame(width: 120, height: 120).clipped().cornerRadius(10)
                                                    } placeholder: {
                                                        RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray5)).frame(width: 120, height: 120).shimmer()
                                                    }.id(imageUrlString)
                                                }
                                                Text(recProduct.name)
                                                    .font(.subheadline)
                                                    .lineLimit(1)
                                                    .frame(width: 120, alignment: .leading)
                                                Text("$\(String(format: "%.2f", recProduct.price))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            addToCartBar
        }
        .onAppear {
            RecommendationEngine.shared.logEvent(productId: product.id, eventType: "view")
        }
    }

    private var productImage: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemGray6)

                if let imageUrlString = product.imageUrl {
                    CachedImageView(urlString: imageUrlString) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: imageHeight)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .shimmer()
                    }
                    .id(imageUrlString)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: geometry.size.width, height: imageHeight)
            .clipped()
        }
        .frame(height: imageHeight)
    }

    private var addToCartBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: {
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
                cartManager.addToCart(product: product)
            }) {
                Label("Add to Cart", systemImage: "cart.badge.plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemBackground))
    }
}
