import SwiftUI

struct ProductListView: View {
    @EnvironmentObject private var viewModel: ProductViewModel
    @StateObject private var searchViewModel = SearchViewModel()
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    @State private var showProfile = false
    @State private var showFilters = false
    @ObservedObject private var recoEngine = RecommendationEngine.shared
    @StateObject private var visualVM = VisualSearchViewModel()
    
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
            var result = viewModel.products
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
                            
                            // MARK: — Custom Search Bar (with Visual Search)
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 15))

                                TextField("Search products, styles, or moods…", text: $searchViewModel.searchText)
                                    .font(.system(size: 15))
                                    .submitLabel(.search)
                                    .onSubmit {
                                        searchViewModel.performSearch(query: searchViewModel.searchText)
                                    }

                                // Camera button
                                Button {
                                    visualVM.showSourceDialog = true
                                } label: {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                .buttonStyle(ScaleButtonStyle())

                                // Clear button
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
                            .padding(.bottom, 4)

                            // MARK: — Filters/Categories Chips
                            if searchViewModel.hasSearched {
                                if searchViewModel.selectedCategory != nil || searchViewModel.maxPrice != nil || !searchViewModel.selectedTags.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            if let cat = searchViewModel.selectedCategory {
                                                SearchChipView(title: cat, isSelected: true) { searchViewModel.selectedCategory = nil }
                                            }
                                            if let price = searchViewModel.maxPrice {
                                                SearchChipView(title: "Under $\(Int(price))", isSelected: true) { searchViewModel.maxPrice = nil }
                                            }
                                            ForEach(Array(searchViewModel.selectedTags), id: \.self) { tag in
                                                SearchChipView(title: tag.capitalized, isSelected: true) { searchViewModel.toggleTag(tag) }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                }
                            } else if !categories.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        CategoryChip(title: "All", isSelected: searchViewModel.selectedCategory == nil) {
                                            withAnimation(.spring(response: 0.3)) { searchViewModel.selectedCategory = nil }
                                        }
                                        ForEach(categories, id: \.self) { category in
                                            CategoryChip(title: category, isSelected: searchViewModel.selectedCategory == category) {
                                                withAnimation(.spring(response: 0.3)) { searchViewModel.selectedCategory = category }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                            
                            // MARK: — AI Recommendation Carousel
                            if !searchViewModel.hasSearched && searchViewModel.selectedCategory == nil && !recommendedProducts.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .center, spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
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
                            
                            // MARK: — Search Results Header
                            if searchViewModel.hasSearched {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(searchViewModel.searchResults.count) results for \"\(searchViewModel.searchText)\"")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button(action: { showFilters = true }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "line.3.horizontal.decrease.circle")
                                            Text("Filter")
                                        }
                                        .font(.caption)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            }
                            
                            // MARK: — Product Grid
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(displayedProducts) { product in
                                    NavigationLink(destination: ProductDetailView(product: product)) {
                                        ProductCardView(product: product)
                                            .onAppear {
                                                if product.id == displayedProducts.last?.id {
                                                    searchViewModel.loadMore()
                                                }
                                            }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 16)
                            
                            if searchViewModel.hasMoreResults && searchViewModel.hasSearched {
                                ProgressView()
                                    .padding(.vertical, 20)
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.fetchProducts()
                        await recoEngine.fetchRecommendations()
                    }
                    .transition(.opacity.animation(.easeIn(duration: 0.3)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.isLoading || searchViewModel.isSearching)
            .navigationTitle("Williams Sonoma")
            .navigationBarTitleDisplayMode(.large)
            // Note: We use the custom search bar instead of .searchable to support the camera button
            .searchSuggestions {
                if let response = searchViewModel.autocompleteResponse {
                    if searchViewModel.searchText.isEmpty {
                        TrendingSearchesView(trending: response.trending) { term in
                            searchViewModel.searchText = term
                            searchViewModel.performSearch(query: term)
                        }
                    } else {
                        SearchSuggestionView(response: response) { term in
                            searchViewModel.searchText = term
                            searchViewModel.performSearch(query: term)
                        }
                    }
                }
            }
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
            // Visual search results sheet
            .sheet(isPresented: $visualVM.showResults) {
                VisualSearchResultsView(vm: visualVM)
            }
            // Camera picker sheet
            .sheet(isPresented: $visualVM.showCamera) {
                CameraPickerRepresentable(selectedImage: $visualVM.capturedImage) {
                    if let img = visualVM.capturedImage {
                        visualVM.handleImageSelected(img)
                    }
                }
                .ignoresSafeArea()
            }
            // Photo library picker sheet
            .sheet(isPresented: $visualVM.showPhotoLibrary) {
                PhotoLibraryPickerRepresentable(selectedImage: $visualVM.capturedImage) {
                    if let img = visualVM.capturedImage {
                        visualVM.handleImageSelected(img)
                    }
                }
                .ignoresSafeArea()
            }
            // Source selection dialog
            .confirmationDialog("Search by Image", isPresented: $visualVM.showSourceDialog, titleVisibility: .visible) {
                Button("Take Photo") { visualVM.showCamera = true }
                Button("Choose from Library") { visualVM.showPhotoLibrary = true }
                Button("Cancel", role: .cancel) {}
            }
            // Permission denied alert
            .alert("Permission Required", isPresented: $visualVM.showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(visualVM.permissionMessage)
            }
            .task {
                if viewModel.products.isEmpty {
                    await viewModel.fetchProducts()
                }
            }
        }
    }
}

// MARK: — AI Recommendation Card (Horizontal Carousel)
struct AIRecommendationCard: View {
    let product: Product
    
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
                
                // AI Badge
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .bold))
                    Text("AI Pick")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.75))
                .clipShape(Capsule())
                .padding(8)
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
                    Text(reasoning)
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
    }
}

// MARK: — Product Grid Card
struct ProductCardView: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            ZStack {
                if let imageUrlString = product.imageUrl {
                    CachedImageView(urlString: imageUrlString) { image in
                        GeometryReader { geo in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.width)
                                .clipped()
                        }
                        .aspectRatio(1, contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(1, contentMode: .fit)
                            .shimmer()
                    }
                    .id(imageUrlString)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 0))
            
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
            }
            .padding(10)
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
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
