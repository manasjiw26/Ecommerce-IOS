import SwiftUI

struct ProductListView: View {
    @EnvironmentObject private var viewModel: ProductViewModel
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var showProfile = false
    @ObservedObject private var recoEngine = RecommendationEngine.shared
    
    var categories: [String] {
        let allCategories = viewModel.products.compactMap { $0.category }
        return Array(Set(allCategories)).sorted()
    }
    
    var recommendedProducts: [Product] {
        return recoEngine.recommendedProducts
    }
    
    var filteredProducts: [Product] {
        var result = viewModel.products
        
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ScrollView {
                        VStack(spacing: 0) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                SkeletonCategoryRow()
                            }
                            SkeletonProductGrid()
                        }
                    }
                    .transition(.opacity)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Text("Oops!")
                            .font(.title)
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") {
                            Task {
                                await viewModel.fetchProducts()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            if !categories.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                                            withAnimation { selectedCategory = nil }
                                        }
                                        ForEach(categories, id: \.self) { category in
                                            CategoryChip(title: category, isSelected: selectedCategory == category) {
                                                withAnimation { selectedCategory = category }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                }
                            }
                            
                            if searchText.isEmpty && selectedCategory == nil && !recommendedProducts.isEmpty {
                                VStack(alignment: .leading) {
                                    Text("Recommended for You")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .padding(.horizontal)
                                        .padding(.top, 10)
                                        
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(recommendedProducts) { product in
                                                NavigationLink(destination: ProductDetailView(product: product)) {
                                                    ProductCardView(product: product)
                                                        .frame(width: 160)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    
                                    Divider()
                                        .padding(.vertical, 10)
                                }
                            }
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(filteredProducts) { product in
                                    NavigationLink(destination: ProductDetailView(product: product)) {
                                        ProductCardView(product: product)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding()
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search products...")
                    .refreshable {
                        await viewModel.fetchProducts()
                    }
                    .transition(.opacity.animation(.easeIn(duration: 0.3)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
            .navigationTitle("ShopEase")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showProfile = true
                    }) {
                        Image(systemName: "person.crop.circle")
                            .imageScale(.large)
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                NavigationView {
                    ProfileView(onLogout: {
                        NotificationCenter.default.post(name: .userDidLogout, object: nil)
                    })
                }
            }
            .task {
                if viewModel.products.isEmpty {
                    await viewModel.fetchProducts()
                }
            }
        }
    }
}

struct ProductCardView: View {
    let product: Product
    @State private var retryToken = UUID()
    
    var body: some View {
        VStack(alignment: .leading) {
            if let imageUrlString = product.imageUrl {
                CachedImageView(urlString: imageUrlString) { image in
                    GeometryReader { geometry in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipped()
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .aspectRatio(1, contentMode: .fit)
                        .shimmer()
                }
                .id(imageUrlString)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
                    .cornerRadius(10)
            }
            
            Text(product.name)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Text("$\(String(format: "%.2f", product.price))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

struct ProductListView_Previews: PreviewProvider {
    static var previews: some View {
        ProductListView()
            .environmentObject(ProductViewModel())
            .environmentObject(CartManager())
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.primary : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? Color(UIColor.systemBackground) : Color.primary)
                .clipShape(Capsule())
        }
    }
}

