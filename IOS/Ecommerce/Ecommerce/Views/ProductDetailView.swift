import SwiftUI
import UIKit

struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var productViewModel: ProductViewModel
    @ObservedObject private var recoEngine = RecommendationEngine.shared
    @State private var similarProducts: [Product] = []
    @State private var isLoadingSimilar = true
    private let imageHeight: CGFloat = 340
    
    var quantityInCart: Int {
        cartManager.items.first(where: { $0.product.id == product.id })?.quantity ?? 0
    }
    
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
                    if isLoadingSimilar {
                        Divider().padding(.top, 4)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.subheadline)
                                Text("Suggested Products")
                                    .font(.headline)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(0..<3) { _ in
                                        Rectangle()
                                            .fill(Color(.systemGray5))
                                            .frame(width: 130, height: 180)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .shimmer()
                                    }
                                }
                            }
                        }
                    } else if !similarProducts.isEmpty {
                        Divider()
                            .padding(.top, 4)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.subheadline)
                                Text("Suggested Products")
                                    .font(.headline)
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(similarProducts) { recProduct in
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
        .task {
            // Load similar products asynchronously
            let results = await recoEngine.fetchSimilarProducts(to: product)
            // Update state on the main thread safely
            await MainActor.run {
                self.similarProducts = results
                self.isLoadingSimilar = false
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
                
                if quantityInCart > 0 {
                    // Counter UI
                    HStack(spacing: 20) {
                        Button(action: {
                            let impactMed = UIImpactFeedbackGenerator(style: .medium)
                            impactMed.impactOccurred()
                            cartManager.removeFromCart(product: product)
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                        }
                        
                        Text("\(quantityInCart)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(minWidth: 20)
                        
                        Button(action: {
                            let impactMed = UIImpactFeedbackGenerator(style: .medium)
                            impactMed.impactOccurred()
                            cartManager.addToCart(product: product)
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                        }
                        .disabled(product.stock != nil && quantityInCart >= (product.stock ?? 0))
                        .opacity(product.stock != nil && quantityInCart >= (product.stock ?? 0) ? 0.5 : 1.0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.primary)
                    .clipShape(Capsule())
                } else {
                    // Add to Cart Button
                    Button(action: {
                        let impactMed = UIImpactFeedbackGenerator(style: .medium)
                        impactMed.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            cartManager.addToCart(product: product)
                        }
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
                    .disabled(product.stock != nil && (product.stock ?? 0) <= 0)
                    .opacity(product.stock != nil && (product.stock ?? 0) <= 0 ? 0.5 : 1.0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemBackground))
    }
}
