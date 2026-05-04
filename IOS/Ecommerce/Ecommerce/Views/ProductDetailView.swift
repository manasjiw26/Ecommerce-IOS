import SwiftUI

struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject var cartManager: CartManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let imageUrlString = product.imageUrl {
                    CachedImageView(urlString: imageUrlString) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                            .clipped()
                    } placeholder: {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                            .background(Color.gray.opacity(0.1))
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 300)
                        .overlay(
                            Image(systemName: "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    if let category = product.category {
                        Text(category.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(product.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
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
                    }
                }
                .padding()
                
                Button(action: {
                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                    impactMed.impactOccurred()
                    cartManager.addToCart(product: product)
                }) {
                    Text("Add to Cart")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let category = product.category {
                RecommendationEngine.shared.logView(for: category)
            }
        }
    }
}
