import SwiftUI

// MARK: - Search Phase
private enum SearchPhase: Equatable {
    case idle       // empty query, not yet searched
    case typing     // has text, autocomplete suggestions active
    case loading    // search in flight
    case results    // submitted, results ready
    case empty      // submitted, zero results
}

// MARK: - SearchOverlayView
struct SearchOverlayView: View {
    @ObservedObject var searchViewModel: SearchViewModel
    @ObservedObject private var recoEngine = RecommendationEngine.shared
    @Environment(\.dismiss) private var dismiss

    @FocusState private var isSearchFocused: Bool
    @StateObject private var visualVM = VisualSearchViewModel()
    @State private var showFilters = false

    private var phase: SearchPhase {
        if searchViewModel.isSearching && searchViewModel.hasSearched { return .loading }
        if searchViewModel.searchText.isEmpty { return .idle }
        if searchViewModel.hasSearched {
            return searchViewModel.searchResults.isEmpty ? .empty : .results
        }
        return .typing
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Capsule Search Bar ──────────────────────────────────────
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(Color(UIColor.systemBackground))

                // ── Thin separator ──────────────────────────────────────────
                Rectangle()
                    .fill(Color(UIColor.separator).opacity(0.4))
                    .frame(height: 0.5)




                // ── Phase-driven content ────────────────────────────────────
                Group {
                    switch phase {
                    case .idle:    idleView
                    case .typing:  typingView
                    case .loading: loadingView
                    case .results: resultsView
                    case .empty:   emptyView
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: phase)
            }
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
        .sheet(isPresented: $showFilters) {
            SearchFilterSheet(viewModel: searchViewModel)
        }
        .confirmationDialog("Visual Search", isPresented: $visualVM.showSourceDialog, titleVisibility: .visible) {
            Button("Camera")        { visualVM.showCamera = true }
            Button("Photo Library") { visualVM.showPhotoLibrary = true }
            Button("Cancel", role: .cancel) {}
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
    }

    // MARK: - Capsule Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            // Capsule search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(Color(.placeholderText))

                TextField("Search", text: $searchViewModel.searchText)
                    .font(.system(size: 17))
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        searchViewModel.performSearch(query: searchViewModel.searchText)
                        isSearchFocused = false
                    }

                if !searchViewModel.searchText.isEmpty {
                    Button {
                        searchViewModel.searchText = ""
                        isSearchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundColor(Color(.systemGray3))
                    }
                } else {
                    Button {
                        visualVM.showSourceDialog = true
                    } label: {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 15))
                            .foregroundColor(Color(.placeholderText))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(UIColor.systemGray6))
            .clipShape(Capsule())

            // Circular X dismiss button (replaces text Cancel)
            Button {
                isSearchFocused = false
                dismiss()
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
    }

    // MARK: - Active Filter Chips
    @ViewBuilder
    private var activeFilterChipsRow: some View {
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
                .padding(.vertical, 10)
            }
            Rectangle()
                .fill(Color(UIColor.separator).opacity(0.4))
                .frame(height: 0.5)
        }
    }

    // MARK: - Idle State (premium structured layout)
    private var idleView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Recently Viewed ───────────────────────────────────────
                if !recoEngine.recentlyViewedProducts.isEmpty {
                    SectionLabel(title: "Recently Viewed")
                        .padding(.top, 28)

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

                // ── Recent Searches ───────────────────────────────────────
                if let response = searchViewModel.autocompleteResponse,
                   !response.recent.isEmpty {
                    SectionLabel(title: "Recent Searches")
                        .padding(.top, recoEngine.recentlyViewedProducts.isEmpty ? 28 : 0)

                    VStack(spacing: 0) {
                        ForEach(Array(response.recent.enumerated()), id: \.element) { idx, term in
                            RecentSearchRow(term: term) {
                                searchViewModel.searchText = term
                                searchViewModel.performSearch(query: term)
                                isSearchFocused = false
                            }
                            if idx < response.recent.count - 1 {
                                Divider()
                                    .padding(.leading, 48)
                            }
                        }
                    }
                    .padding(.bottom, 28)
                }

                // ── Trending Searches ─────────────────────────────────────
                if let response = searchViewModel.autocompleteResponse,
                   !response.trending.isEmpty {
                    SectionLabel(title: "Trending")
                        .padding(.top, (recoEngine.recentlyViewedProducts.isEmpty &&
                                        (searchViewModel.autocompleteResponse?.recent.isEmpty ?? true)) ? 28 : 0)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(response.trending, id: \.self) { term in
                                Button {
                                    searchViewModel.searchText = term
                                    searchViewModel.performSearch(query: term)
                                    isSearchFocused = false
                                } label: {
                                    Text(term.capitalized)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 9)
                                        .background(Color(UIColor.systemGray6))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                    }
                    .padding(.bottom, 28)
                }


            }
        }
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Typing State (live suggestions)
    private var typingView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if let response = searchViewModel.autocompleteResponse {

                    // Product matches
                    if !response.products.isEmpty {
                        SectionLabel(title: "Products").padding(.top, 20)
                        VStack(spacing: 0) {
                            ForEach(Array(response.products.enumerated()), id: \.element.id) { idx, product in
                                AutocompleteRow(
                                    icon: "magnifyingglass",
                                    label: product.name,
                                    sublabel: product.category,
                                    trailingIcon: "arrow.up.left"
                                ) {
                                    searchViewModel.searchText = product.name
                                    searchViewModel.performSearch(query: product.name)
                                    isSearchFocused = false
                                }
                                if idx < response.products.count - 1 {
                                    Divider().padding(.leading, 48)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }

                    // Category matches
                    if !response.categories.isEmpty {
                        SectionLabel(title: "Categories")
                        VStack(spacing: 0) {
                            ForEach(Array(response.categories.enumerated()), id: \.element) { idx, cat in
                                AutocompleteRow(
                                    icon: "folder",
                                    label: "Search in \(cat)",
                                    trailingIcon: "chevron.right"
                                ) {
                                    searchViewModel.selectedCategory = cat
                                    searchViewModel.applyFilters()
                                    isSearchFocused = false
                                }
                                if idx < response.categories.count - 1 {
                                    Divider().padding(.leading, 48)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }

                    // Recent matches
                    if !response.recent.isEmpty {
                        SectionLabel(title: "Recent")
                        VStack(spacing: 0) {
                            ForEach(Array(response.recent.enumerated()), id: \.element) { idx, term in
                                AutocompleteRow(
                                    icon: "clock",
                                    label: term,
                                    trailingIcon: "arrow.up.left"
                                ) {
                                    searchViewModel.searchText = term
                                    searchViewModel.performSearch(query: term)
                                    isSearchFocused = false
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
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Loading
    private var loadingView: some View {
        ScrollView(showsIndicators: false) {
            SkeletonProductGrid()
                .padding(.top, 16)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Results
    private var resultsView: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Results header: count + filter button
                HStack(alignment: .center) {
                    Text("\(searchViewModel.searchResults.count) result\(searchViewModel.searchResults.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        showFilters = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 12, weight: .medium))
//                            Text("Filter")
//                                .font(.caption)
//                                .fontWeight(.medium)
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(UIColor.systemGray6))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // Active filter chips (shown when filters applied)
                activeFilterChipsRow

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

    // MARK: - Empty State
    private var emptyView: some View {
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
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Section Label
private struct SectionLabel: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 2)
    }
}

// MARK: - Recently Viewed Card
private struct RecentlyViewedCard: View {
    let product: Product
    private let size: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Product image
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

            // Product name
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

// MARK: - Recent Search Row
private struct RecentSearchRow: View {
    let term: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                    .foregroundColor(Color(.tertiaryLabel))
                    .frame(width: 20)

                Text(term)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "arrow.up.left")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Autocomplete Row (typing state)
private struct AutocompleteRow: View {
    let icon: String
    let label: String
    var sublabel: String? = nil
    var trailingIcon: String = "arrow.up.left"
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

                Image(systemName: trailingIcon)
                    .font(.system(size: 12))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
