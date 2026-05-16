import SwiftUI
import UIKit

struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var productViewModel: ProductViewModel
    @ObservedObject private var recoEngine = RecommendationEngine.shared
    private let imageHeight: CGFloat = 340
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: — Hero Image
                productImage
                
                // MARK: — Product Info
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Category + Name + Price
                    VStack(alignment: .leading, spacing: 8) {
                        if let category = product.category {
                            Text(category.uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .tracking(1.5)
                        }
                        
                        Text(product.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("$\(String(format: "%.2f", product.price))")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    // Stock indicator
                    if let stock = product.stock {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(stock > 0 ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(stock > 0 ? "In Stock (\(stock) remaining)" : "Out of Stock")
                                .font(.caption)
                                .foregroundColor(stock > 0 ? .green : .red)
                        }
                    }
                    
                    Divider()
                    
                    // AI Reasoning Card (only shown if AI recommended this)
                    if let reasoning = product.aiReasoning {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Why we picked this")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                Text(reasoning)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .background(Color(UIColor.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        
                        Divider()
                    }
                    
                    // Description
                    if let description = product.description {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About This Product")
                                .font(.headline)
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(4)
                        }
                    }
                    
                    // MARK: — Recommendations Carousel
                    if !recoEngine.recommendedProducts.filter({ $0.id != product.id }).isEmpty {
                        Divider()
                            .padding(.top, 4)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.subheadline)
                                Text("You Might Also Like")
                                    .font(.headline)
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(recoEngine.recommendedProducts) { recProduct in
                                        if recProduct.id != product.id {
                                            NavigationLink(destination: ProductDetailView(product: recProduct)) {
                                                VStack(alignment: .leading, spacing: 0) {
                                                    ZStack(alignment: .topLeading) {
                                                        if let imageUrlString = recProduct.imageUrl {
                                                            CachedImageView(urlString: imageUrlString) { image in
                                                                image.resizable().scaledToFill()
                                                                    .frame(width: 130, height: 130)
                                                                    .clipped()
                                                            } placeholder: {
                                                                Rectangle().fill(Color(.systemGray5))
                                                                    .frame(width: 130, height: 130)
                                                                    .shimmer()
                                                            }
                                                            .id(imageUrlString)
                                                        }
                                                        
                                                        if recProduct.aiReasoning != nil {
                                                            Image(systemName: "sparkles")
                                                                .font(.system(size: 10, weight: .bold))
                                                                .foregroundColor(.white)
                                                                .padding(6)
                                                                .background(Color.black.opacity(0.7))
                                                                .clipShape(Circle())
                                                                .padding(6)
                                                        }
                                                    }
                                                    .frame(width: 130, height: 130)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                                    
                                                    VStack(alignment: .leading, spacing: 3) {
                                                        Text(recProduct.name)
                                                            .font(.caption)
                                                            .fontWeight(.medium)
                                                            .lineLimit(2)
                                                            .frame(width: 130, alignment: .leading)
                                                        Text("$\(String(format: "%.2f", recProduct.price))")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                        
                                                        if let reasoning = recProduct.aiReasoning {
                                                            Text(reasoning)
                                                                .font(.caption2)
                                                                .foregroundColor(.secondary)
                                                                .italic()
                                                                .lineLimit(2)
                                                                .frame(width: 130, alignment: .leading)
                                                                .padding(.top, 1)
                                                        }
                                                    }
                                                    .padding(.top, 8)
                                                }
                                                .frame(width: 130)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            addToCartBar
        }
        .onAppear {
            RecommendationEngine.shared.logEvent(productId: product.id, eventType: "view")
            productViewModel.activeProductId = product.id
        }
        .onDisappear {
            if productViewModel.activeProductId == product.id {
                productViewModel.activeProductId = nil
            }
        }
    }

    // MARK: — Hero Image
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
                        .frame(width: 60, height: 60)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: geometry.size.width, height: imageHeight)
        }
        .frame(height: imageHeight)
    }

    // MARK: — Add to Cart Bar
    private var addToCartBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", product.price))")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Button(action: {
                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                    impactMed.impactOccurred()
                    cartManager.addToCart(product: product)
                }) {
                    Label("Add to Cart", systemImage: "cart.badge.plus")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.primary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemBackground))
    }
}
