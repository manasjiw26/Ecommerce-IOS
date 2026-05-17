import SwiftUI

// MARK: - Search Phase (file-private)
private enum SearchPhase: Equatable {
    case idle, typing, loading, results, empty
}

// MARK: - ProductListView
struct ProductListView: View {
    @EnvironmentObject private var viewModel: ProductViewModel
    @StateObject private var searchViewModel = SearchViewModel()
    @ObservedObject private var recoEngine = RecommendationEngine.shared

    @State private var showProfile = false
    @State private var showFilters = false
    @State private var showSourceTypeDialog = false
    @ObservedObject private var recoEngine = RecommendationEngine.shared
    
    var categories: [String] {
        Array(Set(viewModel.products.compactMap { $0.category })).sorted()
    }

    var recommendedProducts: [Product] {
        recoEngine.recommendedProducts
    }

    var displayedProducts: [Product] {
        if searchViewModel.hasSearched {
            return searchViewModel.searchResults
        }
        var result = viewModel.products
        if let category = searchViewModel.selectedCategory {
            result = result.filter { $0.category == category }
        }
        return result
    }

    private var searchPhase: SearchPhase {
        if searchViewModel.isSearching && searchViewModel.hasSearched { return .loading }
        if searchViewModel.searchText.isEmpty { return .idle }
        if searchViewModel.hasSearched {
            return searchViewModel.searchResults.isEmpty ? .empty : .results
        }
        return .typing
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
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
                            
                            // MARK: — AI Recommendation Carousel
                            if !searchViewModel.hasSearched && searchViewModel.selectedCategory == nil && !recommendedProducts.isEmpty {
                                RecommendationCarouselView(recommendedProducts: recommendedProducts)
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
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.82, blendDuration: 0.1), value: isSearchActive)
            .navigationTitle(isSearchActive ? "" : "Williams Sonoma")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !isSearchActive {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showProfile = true } label: {
                            Image(systemName: "person.crop.circle")
                                .imageScale(.large)
                                .foregroundColor(.primary)
                        }
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
            .sheet(isPresented: $visualVM.showSourceDialog) {
                VisualSearchModeSheet { mode in
                    visualVM.searchMode = mode
                    visualVM.showSourceDialog = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showSourceTypeDialog = true
                    }
                }
            }
            .sheet(isPresented: $showSourceTypeDialog) {
                VisualSearchSourceSheet(
                    onCamera:  { visualVM.showCamera       = true },
                    onLibrary: { visualVM.showPhotoLibrary = true }
                )
            }
            .sheet(isPresented: $visualVM.showCamera) {
                CameraPickerRepresentable(selectedImage: $visualVM.capturedImage) {
                    if let img = visualVM.capturedImage { visualVM.handleImageSelected(img) }
                }
            }
            .sheet(isPresented: $visualVM.showPhotoLibrary) {
                PhotoLibraryPickerRepresentable(selectedImage: $visualVM.capturedImage) {
                    if let img = visualVM.capturedImage { visualVM.handleImageSelected(img) }
                }
            }
            .sheet(isPresented: $visualVM.showResults) {
                VisualSearchResultsView(vm: visualVM)
            }
            .task {
                if viewModel.products.isEmpty {
                    await viewModel.fetchProducts()
                }
            }
        }
    }

    // MARK: - Active Search Bar (sticky at top)
    private var activeSearchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(Color(.placeholderText))

                TextField("Search", text: $searchViewModel.searchText)
                    .font(.system(size: 17))
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        searchViewModel.performSearch(query: searchViewModel.searchText)
                        searchFocused = false
                    }

                if !searchViewModel.searchText.isEmpty {
                    Button {
                        searchViewModel.searchText = ""
                        searchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundColor(Color(.systemGray3))
                    }
                } else {
                    Button { visualVM.showSourceDialog = true } label: {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 15))
                            .foregroundColor(Color(.placeholderText))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(UIColor.systemBackground))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 2)

            // Circular X dismiss
            Button {
                searchFocused = false
                searchViewModel.searchText = ""
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82, blendDuration: 0.1)) {
                    isSearchActive = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(.secondaryLabel))
                    .frame(width: 32, height: 32)
                    .background(Color(UIColor.systemGray5))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Search Content (phase-driven)
    @ViewBuilder
    private var searchContent: some View {
        Group {
            switch searchPhase {
            case .idle:    searchIdleView
            case .typing:  searchTypingView
            case .loading: searchLoadingView
            case .results: searchResultsView
            case .empty:   searchEmptyView
            }
        }
        .animation(.easeInOut(duration: 0.15), value: searchPhase)
    }

    // MARK: - Idle: Recently Viewed + Recent Searches + Trending (as rows)
    private var searchIdleView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Recently Viewed ──────────────────────────────────
                if !recoEngine.recentlyViewedProducts.isEmpty {
                    SearchSectionLabel(title: "Recently Viewed")
                        .padding(.top, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recoEngine.recentlyViewedProducts) { product in
                                NavigationLink(destination: ProductDetailView(product: product)) {
                                    RecentlyViewedCard(product: product)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                    }
                    .padding(.bottom, 28)
                }

                // ── Recent Searches ──────────────────────────────────
                if let response = searchViewModel.autocompleteResponse,
                   !response.recent.isEmpty {

                    SearchSectionLabel(title: "Recent Searches")
                        .padding(.top, recoEngine.recentlyViewedProducts.isEmpty ? 24 : 0)

                    VStack(spacing: 0) {
                        ForEach(Array(response.recent.enumerated()), id: \.element) { idx, term in
                            SearchTermRow(icon: "clock", label: term) {
                                searchViewModel.searchText = term
                                searchViewModel.performSearch(query: term)
                                searchFocused = false
                            }
                            if idx < response.recent.count - 1 {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .padding(.bottom, 28)
                }

                // ── Trending Searches (rows, not chips) ──────────────
                if let response = searchViewModel.autocompleteResponse,
                   !response.trending.isEmpty {

                    let isFirst = recoEngine.recentlyViewedProducts.isEmpty
                        && (searchViewModel.autocompleteResponse?.recent.isEmpty ?? true)

                    SearchSectionLabel(title: "Trending Searches")
                        .padding(.top, isFirst ? 24 : 0)

                    VStack(spacing: 0) {
                        ForEach(Array(response.trending.enumerated()), id: \.element) { idx, term in
                            SearchTermRow(icon: "arrow.up.right", label: term) {
                                searchViewModel.searchText = term
                                searchViewModel.performSearch(query: term)
                                searchFocused = false
                            }
                            if idx < response.trending.count - 1 {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .padding(.bottom, 28)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Typing: Live Autocomplete Rows
    private var searchTypingView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if let response = searchViewModel.autocompleteResponse {

                    if !response.products.isEmpty {
                        SearchSectionLabel(title: "Products").padding(.top, 20)
                        VStack(spacing: 0) {
                            ForEach(Array(response.products.enumerated()), id: \.element.id) { idx, product in
                                SearchTermRow(icon: "magnifyingglass", label: product.name, sublabel: product.category) {
                                    searchViewModel.searchText = product.name
                                    searchViewModel.performSearch(query: product.name)
                                    searchFocused = false
                                }
                                if idx < response.products.count - 1 {
                                    Divider().padding(.leading, 48)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }

                    if !response.categories.isEmpty {
                        SearchSectionLabel(title: "Categories")
                        VStack(spacing: 0) {
                            ForEach(Array(response.categories.enumerated()), id: \.element) { idx, cat in
                                SearchTermRow(icon: "folder", label: "Search in \(cat)") {
                                    searchViewModel.selectedCategory = cat
                                    searchViewModel.applyFilters()
                                    searchFocused = false
                                }
                                if idx < response.categories.count - 1 {
                                    Divider().padding(.leading, 48)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }

                    if !response.recent.isEmpty {
                        SearchSectionLabel(title: "Recent")
                        VStack(spacing: 0) {
                            ForEach(Array(response.recent.enumerated()), id: \.element) { idx, term in
                                SearchTermRow(icon: "clock", label: term) {
                                    searchViewModel.searchText = term
                                    searchViewModel.performSearch(query: term)
                                    searchFocused = false
                                }
                                if idx < response.recent.count - 1 {
                                    Divider().padding(.leading, 48)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Loading
    private var searchLoadingView: some View {
        ScrollView(showsIndicators: false) {
            SkeletonProductGrid().padding(.top, 16)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Results
    private var searchResultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Header: count + filter button
                HStack {
                    Text("\(searchViewModel.searchResults.count) result\(searchViewModel.searchResults.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button { showFilters = true } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 34, height: 34)
                            .background(Color(UIColor.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 1)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // Active filter chips
                activeFilterChips

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(searchViewModel.searchResults) { product in
                        NavigationLink(destination: ProductDetailView(product: product)) {
                            ProductCardView(product: product)
                                .onAppear {
                                    if product.id == searchViewModel.searchResults.last?.id {
                                        searchViewModel.loadMore()
                                    }
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)

                if searchViewModel.hasMoreResults {
                    ProgressView()
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Empty
    private var searchEmptyView: some View {
        ScrollView(showsIndicators: false) {
            SearchEmptyStateView(
                query: searchViewModel.searchText,
                trending: searchViewModel.autocompleteResponse?.trending ?? [],
                onTrendingTap: { term in
                    searchViewModel.searchText = term
                    searchViewModel.performSearch(query: term)
                }
            )
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Active Filter Chips
    @ViewBuilder
    private var activeFilterChips: some View {
        let hasFilters = searchViewModel.selectedCategory != nil
            || searchViewModel.maxPrice != nil
            || !searchViewModel.selectedTags.isEmpty

        if hasFilters {
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
                .padding(.bottom, 10)
            }
        }
    }

    // MARK: - Home Content (when search is not active)
    private var homeContent: some View {
        Group {
            if viewModel.isLoading {
                ScrollView {
                    VStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) { SkeletonCategoryRow() }
                        SkeletonProductGrid()
                    }
                }
                .transition(.opacity)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Something went wrong").font(.headline)
                    Text(errorMessage)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Try Again") { Task { await viewModel.fetchProducts() } }
                        .buttonStyle(.borderedProminent)
                        .tint(.primary)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: — Search Pill (tapping activates inline search)
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                isSearchActive = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                searchFocused = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(.placeholderText))

                                Text("Search")
                                    .font(.system(size: 17))
                                    .foregroundColor(Color(.placeholderText))

                                Spacer()

                                Image(systemName: "viewfinder")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(.placeholderText))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(Color(UIColor.systemBackground))
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                        // MARK: — Category Chips
                        if !categories.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    CategoryChip(title: "All", isSelected: searchViewModel.selectedCategory == nil) {
                                        withAnimation(.spring(response: 0.3)) {
                                            searchViewModel.selectedCategory = nil
                                        }
                                    }
                                    ForEach(categories, id: \.self) { category in
                                        CategoryChip(title: category, isSelected: searchViewModel.selectedCategory == category) {
                                            withAnimation(.spring(response: 0.3)) {
                                                searchViewModel.selectedCategory = category
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            }
                        }

                        // MARK: — AI Recommendation Carousel
                        if searchViewModel.selectedCategory == nil && !recommendedProducts.isEmpty {
                            RecommendationCarouselView(recommendedProducts: recommendedProducts)
                        }

                        // MARK: — Product Grid
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(displayedProducts) { product in
                                NavigationLink(destination: ProductDetailView(product: product)) {
                                    ProductCardView(product: product)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                    }
                }
                .refreshable {
                    await viewModel.fetchProducts()
                    await recoEngine.fetchRecommendations()
                }
                .transition(.opacity.animation(.easeIn(duration: 0.3)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isLoading)
    }
}

// MARK: - Search Section Label
private struct SearchSectionLabel: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
    }
}

// MARK: - Search Term Row (recent, trending, autocomplete — uniform style)
private struct SearchTermRow: View {
    let icon: String
    let label: String
    var sublabel: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(.tertiaryLabel))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if let sub = sublabel {
                        Text(sub)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Recently Viewed Card
private struct RecentlyViewedCard: View {
    let product: Product
    private let size: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(UIColor.systemGray6))
                    .frame(width: size, height: size)

                if let url = product.imageUrl {
                    CachedImageView(urlString: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipped()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: size, height: size)
                            .shimmer()
                    }
                    .id(url)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(Color(.systemGray3))
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)

            Text(product.name)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(width: size, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .frame(width: size)
    }
}

// MARK: - Product Grid Card
struct ProductCardView: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 0))

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
            .frame(height: 80, alignment: .topLeading)
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Category Chip
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

// MARK: — Visual Search Mode Sheet

struct VisualSearchModeSheet: View {
    let onSelect: (VisualSearchViewModel.SearchMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Visual Search")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundStyle(.primary)
                Text("How would you like to search?")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            // Cards
            VStack(spacing: 10) {
                VisualSearchModeCard(
                    icon: "viewfinder.circle.fill",
                    iconBackground: .black,
                    iconColor: .white,
                    title: "Search Object",
                    subtitle: "Find a specific item by photo",
                    action: { onSelect(.object) }
                )
                VisualSearchModeCard(
                    icon: "sparkles",
                    iconBackground: Color(.systemIndigo).opacity(0.12),
                    iconColor: Color(.systemIndigo),
                    title: "Search Aesthetic",
                    subtitle: "Match a room's mood & palette",
                    action: { onSelect(.aesthetic) }
                )
            }

            // Footer note
            HStack(spacing: 4) {
                Image(systemName: "camera.fill")
                Text("Camera access required")
            }
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .presentationDetents([.height(320)])
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
    }
}

// MARK: — Visual Search Mode Card

struct VisualSearchModeCard: View {
    let icon: String
    let iconBackground: Color
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon tile
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconBackground)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(iconColor)
                    )

                // Labels
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color(.separator), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        ._onButtonGesture(pressing: { isPressed = $0 }, perform: {})
    }
}

// MARK: — Visual Search Source Sheet (Camera vs Library)

struct VisualSearchSourceSheet: View {
    let onCamera:  () -> Void
    let onLibrary: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose Source")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Where is your photo?")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            // Cards
            VStack(spacing: 10) {
                VisualSearchModeCard(
                    icon: "camera.fill",
                    iconBackground: Color(.systemGreen).opacity(0.12),
                    iconColor: Color(.systemGreen),
                    title: "Take a Photo",
                    subtitle: "Use your camera right now",
                    action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onCamera() }
                    }
                )
                VisualSearchModeCard(
                    icon: "photo.on.rectangle.angled",
                    iconBackground: Color(.systemBlue).opacity(0.12),
                    iconColor: Color(.systemBlue),
                    title: "Photo Library",
                    subtitle: "Pick from your saved photos",
                    action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onLibrary() }
                    }
                )
            }

            // Footer
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                Text("Photos stay on your device")
            }
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .presentationDetents([.height(300)])
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
    }
}

#Preview {
    ProductListView()
        .environmentObject(ProductViewModel())
        .environmentObject(CartManager())
}
