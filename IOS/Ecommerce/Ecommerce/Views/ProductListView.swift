import SwiftUI

struct ProductListView: View {
    @EnvironmentObject private var viewModel: ProductViewModel
    @EnvironmentObject var aiPresence: AIPresenceManager
    @StateObject private var searchViewModel = SearchViewModel()
    @StateObject private var visualVM = VisualSearchViewModel()

    private let gridHorizontalPadding: CGFloat = 14
    private let gridColumnSpacing: CGFloat = 14
    private let gridRowSpacing: CGFloat = 16

    @State private var showProfile = false
    @State private var showFilters = false
    @State private var personalizedRefreshToken = UUID()
    @ObservedObject private var recoEngine = RecommendationEngine.shared
    @State private var cachedPersonalizedProducts: [Product] = []

    private var productCardWidth: CGFloat {
        let width = UIScreen.main.bounds.width
        let availableWidth = width - (gridHorizontalPadding * 2) - gridColumnSpacing
        return floor(availableWidth / 2)
    }

    private var productCardHeight: CGFloat {
        productCardWidth + 86
    }

    private var productGridColumns: [GridItem] {
        [
            GridItem(.fixed(productCardWidth), spacing: gridColumnSpacing),
            GridItem(.fixed(productCardWidth), spacing: gridColumnSpacing)
        ]
    }
    
    var categories: [String] {
        let allCategories = viewModel.products.compactMap { $0.category }
        return Array(Set(allCategories)).sorted()
    }
    
    var recommendedProducts: [Product] {
        return recoEngine.recommendedProducts
    }
    
    var displayedProducts: [Product] {
        if searchViewModel.hasSearched {
            return searchViewModel.searchResults
        } else {
            var result = cachedPersonalizedProducts.isEmpty ? viewModel.products : cachedPersonalizedProducts
            if let category = searchViewModel.selectedCategory {
                result = result.filter { $0.category == category }
            }
            return result
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if viewModel.isLoading || searchViewModel.isSearching {
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
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Something went wrong")
                            .font(.headline)
                        Text(errorMessage)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Try Again") {
                            Task { await viewModel.fetchProducts() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.primary)
                    }
                } else if searchViewModel.hasSearched && searchViewModel.searchResults.isEmpty {
                    ScrollView {
                        SearchEmptyStateView(query: searchViewModel.searchText)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            
                            // MARK: — Search Bar (Krish search pipeline) + Camera (NR visual search)
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 15))
                                
                                TextField("Search products, styles, or moods…", text: $searchViewModel.searchText)
                                    .font(.system(size: 15))
                                    .submitLabel(.search)
                                    .onSubmit {
                                        searchViewModel.performSearch(query: searchViewModel.searchText)
                                    }
                                
                                Button {
                                    visualVM.showSourceDialog = true
                                } label: {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                
                                Button {
                                    showFilters = true
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                
                                if !searchViewModel.searchText.isEmpty {
                                    Button {
                                        searchViewModel.searchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 15))
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                            
                            // AI Status Bar
                            AIStatusBar(messages: [
                                "✦ Personalizing your feed",
                                "✦ Prices verified just now",
                                "✦ 3 new arrivals match your taste",
                                "✦ Recommendations refreshed"
                            ])
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                            .padding(.bottom, 2)

                            /*
                             Legacy search UI (kept commented so nothing is lost):
                             - Used SwiftUI `.searchable` + `RecommendationEngine.searchProducts(query:)`
                             - Did not support autocomplete, recent/trending, server-side filters, or pagination
                             */
                            // .searchable(text: $searchText, prompt: "Search products, styles, or moods…")
                            // .onSubmit(of: .search) { recoEngine.searchProducts(query: searchText) }
                            
                            // MARK: — Suggestions (recent/trending/products/categories)
                            if let response = searchViewModel.autocompleteResponse {
                                if searchViewModel.searchText.isEmpty {
                                    TrendingSearchesView(trending: response.trending) { term in
                                        searchViewModel.searchText = term
                                        searchViewModel.performSearch(query: term)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                                } else {
                                    SearchSuggestionView(response: response) { term in
                                        // "Search in <Category>" suggestions currently come through as plain strings.
                                        // If the selected term matches a suggested category, treat it as a category filter
                                        // and keep the user's current query.
                                        if response.categories.contains(term) {
                                            searchViewModel.selectedCategory = term
                                            searchViewModel.applyFilters()
                                        } else {
                                            searchViewModel.searchText = term
                                            searchViewModel.performSearch(query: term)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                                }
                            }
                            
                            // MARK: — Category Chips (works during search too)
                            if !categories.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        CategoryChip(title: "All", isSelected: searchViewModel.selectedCategory == nil) {
                                            withAnimation(.spring(response: 0.3)) {
                                                searchViewModel.selectedCategory = nil
                                                if searchViewModel.hasSearched {
                                                    searchViewModel.applyFilters()
                                                }
                                            }
                                        }
                                        ForEach(categories, id: \.self) { category in
                                            CategoryChip(title: category, isSelected: searchViewModel.selectedCategory == category) {
                                                withAnimation(.spring(response: 0.3)) {
                                                    searchViewModel.selectedCategory = category
                                                    if searchViewModel.hasSearched {
                                                        searchViewModel.applyFilters()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                                }
                            }

                            // MARK: — Filter Chips (only when searching)
                            if searchViewModel.hasSearched {
                                if searchViewModel.selectedCategory != nil || searchViewModel.maxPrice != nil || !searchViewModel.selectedTags.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            if let cat = searchViewModel.selectedCategory {
                                                SearchChipView(title: cat, isSelected: true) {
                                                    searchViewModel.selectedCategory = nil
                                                    searchViewModel.applyFilters()
                                                }
                                            }
                                            if let price = searchViewModel.maxPrice {
                                                SearchChipView(title: "Under $\(Int(price))", isSelected: true) {
                                                    searchViewModel.maxPrice = nil
                                                    searchViewModel.applyFilters()
                                                }
                                            }
                                            ForEach(Array(searchViewModel.selectedTags), id: \.self) { tag in
                                                SearchChipView(title: tag.capitalized, isSelected: true) {
                                                    searchViewModel.toggleTag(tag)
                                                    searchViewModel.applyFilters()
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 8)
                                    }
                                }
                            }
                            
                            // MARK: — Horizontal Shelves (Major Ecommerce Style)
                            if !searchViewModel.hasSearched && searchViewModel.selectedCategory == nil {
                                
                                let promoted = recoEngine.getPromotedProducts(from: viewModel.products)
                                HorizontalProductShelfView(
                                    title: "Featured Events",
                                    systemImage: "star.fill",
                                    products: promoted
                                )
                                
                                let recent = recoEngine.getRecentlyViewedProducts(from: viewModel.products)
                                HorizontalProductShelfView(
                                    title: "Continue Shopping",
                                    systemImage: "clock.arrow.circlepath",
                                    products: recent
                                )
                                
                                if !recommendedProducts.isEmpty {
                                    HorizontalProductShelfView(
                                        title: "Picked For You",
                                        systemImage: "sparkles",
                                        products: recommendedProducts,
                                        showAIPickBadge: true
                                    )
                                }
                                
                                HStack {
                                    Text("More to Explore")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 4)
                            }
                            
                            // MARK: — Product Grid
                            LazyVGrid(columns: productGridColumns, spacing: gridRowSpacing) {
                                ForEach(displayedProducts) { product in
                                    NavigationLink(destination: ProductDetailView(product: product)) {
                                        ProductCardView(
                                            product: product,
                                            width: productCardWidth,
                                            height: productCardHeight
                                        )
                                            .overlay(alignment: .topLeading) {
                                                if product.aiReasoning != nil {
                                                    AISparkBadge(label: "AI Pick", size: .small)
                                                        .padding(8)
                                                }
                                            }
                                            .onAppear {
                                                RecommendationEngine.shared.logEvent(productId: product.id, eventType: "impression")
                                                if searchViewModel.hasSearched && product.id == displayedProducts.last?.id {
                                                    searchViewModel.loadMore()
                                                }
                                            }
                                    }
                                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .id(personalizedRefreshToken)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, gridHorizontalPadding)
                            .padding(.bottom, 16)
                            
                            if searchViewModel.hasMoreResults && searchViewModel.hasSearched {
                                ProgressView()
                                    .padding(.vertical, 20)
                            }
                        }
                    }
                    .refreshable {
                        await refreshPersonalizedHome()
                    }
                    .transition(.opacity.animation(.easeIn(duration: 0.3)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.isLoading || searchViewModel.isSearching)
            .navigationTitle("Williams Sonoma")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showProfile = true }) {
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
            .sheet(isPresented: $showFilters) {
                SearchFilterSheet(viewModel: searchViewModel)
            }
            .confirmationDialog("Visual Search", isPresented: $visualVM.showSourceDialog, titleVisibility: .visible) {
                Button("Camera") { visualVM.showCamera = true }
                Button("Photo Library") { visualVM.showPhotoLibrary = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $visualVM.showCamera) {
                CameraPickerRepresentable(selectedImage: $visualVM.capturedImage) {
                    if let img = visualVM.capturedImage {
                        visualVM.handleImageSelected(img)
                    }
                }
            }
            .sheet(isPresented: $visualVM.showPhotoLibrary) {
                PhotoLibraryPickerRepresentable(selectedImage: $visualVM.capturedImage) {
                    if let img = visualVM.capturedImage {
                        visualVM.handleImageSelected(img)
                    }
                }
            }
            .sheet(isPresented: $visualVM.showResults) {
                VisualSearchResultsView(vm: visualVM)
            }
            .task {
                if viewModel.products.isEmpty {
                    await refreshPersonalizedHome()
                } else if cachedPersonalizedProducts.isEmpty {
                    cachedPersonalizedProducts = recoEngine.personalize(viewModel.products)
                }
            }
            .onChange(of: searchViewModel.isSearching) { _, isSearching in
                aiPresence.isAIActive = isSearching
            }
            .onChange(of: searchViewModel.hasSearched) { _, hasSearched in
                if hasSearched {
                    NotificationCenter.default.post(
                        name: .aiSearchPerformed,
                        object: nil,
                        userInfo: ["query": searchViewModel.searchText]
                    )
                }
            }
        }
    }

    @MainActor
    private func refreshPersonalizedHome() async {
        await viewModel.fetchProducts()
        await recoEngine.fetchRecommendations()
        cachedPersonalizedProducts = recoEngine.personalize(viewModel.products)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            personalizedRefreshToken = UUID()
        }
    }
}



// MARK: — Product Grid Card
struct ProductCardView: View {
    let product: Product
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            productImage
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text("$\(String(format: "%.2f", product.price))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 82, maxHeight: 82, alignment: .topLeading)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
    }

    private var productImage: some View {
        ZStack {
            Color(.systemGray6)

            if let imageUrlString = product.imageUrl, !imageUrlString.isEmpty {
                CachedImageView(urlString: imageUrlString) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .shimmer()
                }
                .id(imageUrlString)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
            }
        }
        .frame(width: width, height: width)
        .clipped()
    }
}

// MARK: — Category Chip
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title.capitalized)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.primary : Color(UIColor.systemBackground))
                .foregroundColor(isSelected ? Color(UIColor.systemBackground) : Color.primary)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(isSelected ? 0 : 0.06), radius: 4, x: 0, y: 2)
        }
    }
}

#Preview {
    ProductListView()
        .environmentObject(ProductViewModel())
        .environmentObject(CartManager())
}
