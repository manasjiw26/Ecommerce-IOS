import SwiftUI

struct RegistryDashboardView: View {
    @State var registry: MockRegistryExtended
    @ObservedObject private var registryService = MockRegistryService.shared
    
    @State private var items: [RegistryItem] = []
    @State private var showingEditSheet = false
    @State private var showingAddProductsSheet = false
    @State private var selectedItemForTagging: RegistryItem? = nil
    @State private var showShareSheet = false
    @State private var isLoadingDashboard = false
    @State private var dashboardLoadingMessage = "Loading registry..."
    
    // Toast Alert States
    @State private var showingToast = false
    @State private var toastMessage = ""
    
    // Swipe Delete Confirmation States
    @State private var itemToDelete: RegistryItem? = nil
    @State private var showingItemDeleteConfirmation = false
    @State private var addingBundleTypes: Set<String> = []
    @State private var selectedProductForDetail: Product? = nil
    @State private var selectedItemForContributors: RegistryItem? = nil
    
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var productViewModel: ProductViewModel
    @Environment(\.dismiss) var dismiss
    
    // Native iOS Share Sheet Helper
    func shareText(_ text: String) {
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let scenes = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scenes.windows.first?.rootViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }
    
    var body: some View {
        ZStack {
            List {
                // MARK: - Header / Hero Section
                Section {
                    ZStack(alignment: .topTrailing) {
                        ZStack(alignment: .bottomLeading) {
                            CachedImageView(urlString: registry.bannerImageUrl) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Rectangle().fill(Color.gray.opacity(0.1))
                            }
                            .frame(height: 200)
                            .clipped()
                            .overlay(Color.black.opacity(0.4))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(registry.type.uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white.opacity(0.8))
                                    .kerning(1.5)
                                
                                Text(registry.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 12) {
                                    Text(registry.date)
                                    Text("•")
                                    Text(registry.location)
                                }
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(16)
                        }
                        
                        Button(action: { showingEditSheet = true }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding(12)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .listRowSeparator(.hidden)
                
                // MARK: - Actions Row (Add Items on the left, Share moved to Top Right Toolbar)
                Section {
                    HStack {
                        Button(action: { showingAddProductsSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Add Items")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .listRowSeparator(.hidden)
                
                // MARK: - Typographic Stat Box
                Section {
                    let fulfilledCount = items.filter { $0.quantityReceived >= $0.quantityRequested && $0.quantityRequested > 0 }.count
                    let remainingCount = items.filter { $0.quantityReceived < $0.quantityRequested || $0.quantityRequested == 0 }.count
                    
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("WISHES FULFILLED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .kerning(1)
                            Text("\(fulfilledCount)")
                                .font(.system(size: 32, weight: .light, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 0.5, height: 44)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("GIFTS REMAINING")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .kerning(1)
                            Text("\(remainingCount)")
                                .font(.system(size: 32, weight: .light, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(Color(UIColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .listRowSeparator(.hidden)
                
                // MARK: - Dynamic Smart Starter Bundles based on Event Type
                Section {
                    let bundles = registryService.starterBundles.isEmpty ? registryService.getSmartBundlesForEvent(type: registry.type) : registryService.starterBundles
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Starter Bundles")
                            .font(.headline)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(bundles) { bundle in
                                    let isAdding = addingBundleTypes.contains(bundle.bundleType)
                                    let isAdded = items.contains { $0.aiReason?.contains("Starter bundle \(bundle.bundleType)") == true }
                                    
                                    RichBundleCard(
                                        title: bundle.title,
                                        subtitle: bundle.subtitle,
                                        imageUrl: bundle.imageUrl,
                                        isAdded: isAdded,
                                        isAdding: isAdding
                                    ) {
                        Task {
                            withAnimation(.easeInOut) {
                                addingBundleTypes.insert(bundle.bundleType)
                            }
                            do {
                                try await MockRegistryService.shared.applySmartBundle(registryId: registry.id, bundleType: bundle.bundleType)
                                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s for backend inserts
                                try await MockRegistryService.shared.fetchRegistryDashboard(registryId: registry.id)
                                await MainActor.run {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                                        items = MockRegistryService.shared.registryItems[registry.id] ?? []
                                    }
                                    toastMessage = "Starter Bundle Added!"
                                    withAnimation(.spring()) {
                                        showingToast = true
                                    }
                                }
                            } catch {
                                await MainActor.run {
                                    toastMessage = error.localizedDescription
                                    withAnimation(.spring()) {
                                        showingToast = true
                                    }
                                }
                            }
                            await MainActor.run {
                                withAnimation(.easeInOut) {
                                    addingBundleTypes.remove(bundle.bundleType)
                                }
                            }
                        }
                    }
                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .listRowSeparator(.hidden)
                
                // MARK: - Registry Items List Section
                Section(header: Text("Your Registry Items").font(.headline).foregroundColor(.primary).padding(.horizontal, 20)) {
                    if items.isEmpty {
                        VStack(spacing: 8) {
                            Text("Your registry is empty.")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text("Try adding a Smart Bundle above or tap Add Items to add custom products.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(items) { item in
                            RegistryItemRow(item: item, registryId: registry.id, onTap: {
                                if let contribs = item.contributions, !contribs.isEmpty {
                                    selectedItemForContributors = item
                                } else if let prod = item.products {
                                    selectedProductForDetail = prod
                                }
                            }, onTagUpdate: {
                                items = MockRegistryService.shared.registryItems[registry.id] ?? []
                            })
                            .listRowBackground(Color.white)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                // Swipe Option 1: Delete with Confirmation
                                Button(role: .destructive) {
                                    itemToDelete = item
                                    showingItemDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                // Swipe Option 2: Tags
                                Button {
                                    selectedItemForTagging = item
                                } label: {
                                    Label("Tags", systemImage: "tag")
                                }
                                .tint(.gray)
                            }
                        }
                    }
                }
                .listRowSeparator(.visible)
            }
            .listStyle(.plain)
            .background(Color.white)
            
            // MARK: - Premium Pop-up HUD Alert (Auto-dismisses in 1.2 seconds)
            if showingToast {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    Text(toastMessage)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.85))
                )
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation {
                            showingToast = false
                        }
                    }
                }
            }

            if isLoadingDashboard {
                RegistryLoadingOverlay(message: dashboardLoadingMessage)
            }
        }
        .onAppear {
            Task {
                await refreshDashboard(message: "Loading registry...")
                await RecommendationEngine.shared.fetchRecommendations()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Native iOS Sharing Button Only! No Done button.
                Button(action: {
                    showShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            RegistryEditView(registry: $registry, items: $items, onSave: {
                Task {
                    await refreshDashboard(message: "Refreshing registry...")
                }
            }, onDelete: {
                dismiss()
            })
        }
        .sheet(isPresented: $showingAddProductsSheet) {
            RegistryAddProductsView(registryId: registry.id) {
                Task {
                    await refreshDashboard(message: "Refreshing items...")
                }
            }
        }
        .sheet(item: $selectedProductForDetail) { product in
            NavigationStack {
                ProductDetailView(product: product, showCloseButton: true)
            }
        }
        .sheet(item: $selectedItemForContributors) { item in
            RegistryItemContributorsView(item: item)
        }
        .sheet(item: $selectedItemForTagging) { item in
            RegistryItemTagEditView(registryId: registry.id, item: item) {
                Task {
                    await refreshDashboard(message: "Updating item...")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            RegistryShareSheetView(registryId: registry.id, fallbackCode: registry.code) { textToShare in
                shareText(textToShare)
            }
        }
        // MARK: - Trailing Item Deletion Confirmation
        .alert("Delete Registry Item", isPresented: $showingItemDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    Task {
                        await MainActor.run {
                            dashboardLoadingMessage = "Deleting item..."
                            isLoadingDashboard = true
                        }
                        do {
                            try await RegistryService.shared.deleteRegistryItem(registryId: registry.id, itemId: item.id)
                            try await registryService.fetchRegistryDashboard(registryId: registry.id)
                            await MainActor.run {
                                items = registryService.registryItems[registry.id] ?? []
                                isLoadingDashboard = false
                            }
                        } catch {
                            await MainActor.run {
                                isLoadingDashboard = false
                                toastMessage = error.localizedDescription
                                withAnimation(.spring()) {
                                    showingToast = true
                                }
                            }
                        }
                    }
                }
                itemToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            if let item = itemToDelete, let product = item.products {
                Text("Are you sure you want to remove \(product.name) from your registry?")
            } else {
                Text("Are you sure you want to remove this item?")
            }
        }
    }

    @MainActor
    private func refreshDashboard(message: String) async {
        dashboardLoadingMessage = message
        isLoadingDashboard = true
        do {
            try await registryService.fetchRegistryDashboard(registryId: registry.id)
            await registryService.fetchStarterBundles(eventType: registry.type)
            items = registryService.registryItems[registry.id] ?? []
        } catch {
            toastMessage = error.localizedDescription
            withAnimation(.spring()) {
                showingToast = true
            }
        }
        isLoadingDashboard = false
    }
}

// MARK: - Registry Edit Sheet with persistent Information Labels

struct RegistryEditView: View {
    @Binding var registry: MockRegistryExtended
    @Binding var items: [RegistryItem]
    @Environment(\.dismiss) var dismiss
    
    @State private var editName = ""
    @State private var editDateString = ""
    @State private var editLocation = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingFallbackEditSheet = false
    
    let onSave: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Registry Details")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Event Name")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        TextField("Enter event name...", text: $editName)
                            .font(.body)
                            .padding(.vertical, 4)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Event Date")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        TextField("Enter date...", text: $editDateString)
                            .font(.body)
                            .padding(.vertical, 4)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Event Location")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        TextField("Enter location (optional)...", text: $editLocation)
                            .font(.body)
                            .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Registry Management")) {
                    Button(action: { showingFallbackEditSheet = true }) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .foregroundColor(.primary)
                            Text("Edit Registry Items")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Text("Delete Registry")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Edit Registry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            MockRegistryService.shared.updateRegistry(
                                id: registry.id,
                                name: editName,
                                date: editDateString,
                                location: editLocation
                            )
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s sleep
                            try? await MockRegistryService.shared.fetchRegistryDashboard(registryId: registry.id)
                            await MainActor.run {
                                if let updated = MockRegistryService.shared.registries.first(where: { $0.id == registry.id }) {
                                    registry = updated
                                }
                                onSave()
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingFallbackEditSheet) {
                RegistryItemsFallbackEditView(registryId: registry.id, items: $items)
            }
            .alert("Delete Registry", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        MockRegistryService.shared.deleteRegistry(id: registry.id)
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        await MainActor.run {
                            onDelete()
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this registry? This action cannot be undone.")
            }
            .onAppear {
                editName = registry.name
                editDateString = registry.date
                editLocation = registry.location
            }
        }
    }
}

struct RegistryItemsFallbackEditView: View {
    let registryId: String
    @Binding var items: [RegistryItem]
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedItemForTagging: RegistryItem? = nil
    @State private var itemToDelete: RegistryItem? = nil
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    Text("No items in registry.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .padding()
                } else {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            CachedImageView(urlString: item.products?.imageUrl ?? "") { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Rectangle().fill(Color.gray.opacity(0.1))
                            }
                            .frame(width: 40, height: 40)
                            .cornerRadius(4)
                            .clipped()
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.products?.name ?? "Product")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                
                                if let tags = item.products?.tags, !tags.isEmpty {
                                    Text(tags.joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                // Edit Tags Button
                                Button(action: {
                                    selectedItemForTagging = item
                                }) {
                                    Text("Tags")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.gray)
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                                
                                // Delete Button
                                Button(action: {
                                    itemToDelete = item
                                    showingDeleteConfirmation = true
                                }) {
                                    Text("Delete")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.red)
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Manage Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.primary)
                }
            }
            .sheet(item: $selectedItemForTagging) { item in
                RegistryItemTagEditView(registryId: registryId, item: item) {
                    Task {
                        try? await MockRegistryService.shared.fetchRegistryDashboard(registryId: registryId)
                        await MainActor.run {
                            items = MockRegistryService.shared.registryItems[registryId] ?? []
                        }
                    }
                }
            }
            .alert("Delete Item", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete {
                        Task {
                            do {
                                MockRegistryService.shared.removeItem(registryId: registryId, itemId: item.id)
                                try? await Task.sleep(nanoseconds: 400_000_000)
                                try? await MockRegistryService.shared.fetchRegistryDashboard(registryId: registryId)
                                await MainActor.run {
                                    items = MockRegistryService.shared.registryItems[registryId] ?? []
                                }
                            }
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove this item from your registry?")
            }
        }
    }
}

// MARK: - Registry Add Products Sheet using Recommendation Engine first

struct RegistryAddProductsView: View {
    let registryId: String
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var productViewModel = ProductViewModel()
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var addingProductIds: Set<Int> = []
    @State private var addedProductIds: Set<Int> = []
    
    let onItemsAdded: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // MARK: — Standardized Search Bar (Matches ProductListView)
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
                        
                        if !searchViewModel.searchText.isEmpty {
                            Button {
                                searchViewModel.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 15))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    
                    if searchViewModel.isSearching {
                        RegistryInlineLoadingView(message: "Searching catalog...")
                    } else if productViewModel.isLoading && !searchViewModel.hasSearched {
                        RegistryInlineLoadingView(message: "Loading suggestions...")
                    } else if let errorMessage = productViewModel.errorMessage, productViewModel.products.isEmpty && !searchViewModel.hasSearched {
                        VStack(spacing: 10) {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task { await productViewModel.fetchProducts() }
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(Color.black)
                            .cornerRadius(6)
                        }
                        .padding(.top, 40)
                        .padding(.horizontal, 20)
                    } else {
                        // Display search results or suggestions
                        let showSearchResults = searchViewModel.hasSearched
                        let productsToDisplay: [Product] = {
                            if showSearchResults {
                                return searchViewModel.searchResults
                            } else {
                                let initial = productViewModel.products.isEmpty ? RecommendationEngine.shared.recommendedProducts : productViewModel.products
                                return initial.filter {
                                    searchViewModel.searchText.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchViewModel.searchText) || ($0.category ?? "").localizedCaseInsensitiveContains(searchViewModel.searchText)
                                }
                            }
                        }()
                        
                        if showSearchResults && productsToDisplay.isEmpty {
                            ScrollView {
                                SearchEmptyStateView(query: searchViewModel.searchText)
                            }
                        } else {
                            List {
                                Section(header: Text(showSearchResults ? "Search Results" : (searchViewModel.searchText.isEmpty ? "Suggestions" : "Filtered suggestions")).font(.caption).fontWeight(.bold).foregroundColor(.secondary)) {
                                    ForEach(productsToDisplay) { product in
                                        HStack(spacing: 12) {
                                            CachedImageView(urlString: product.imageUrl ?? "") { img in
                                                img.resizable().scaledToFill()
                                            } placeholder: {
                                                Rectangle().fill(Color.gray.opacity(0.1))
                                            }
                                            .frame(width: 50, height: 50)
                                            .cornerRadius(6)
                                            .clipped()
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(product.name)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                Text(product.category ?? "General")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text("$\(String(format: "%.2f", product.price))")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.primary)
                                            }
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                Task {
                                                    await MainActor.run {
                                                        addingProductIds.insert(product.id)
                                                    }
                                                    do {
                                                        try await MockRegistryService.shared.addProductToRegistry(registryId: registryId, product: product)
                                                        await MainActor.run {
                                                            addedProductIds.insert(product.id)
                                                            onItemsAdded()
                                                            toastMessage = "Added \(product.name)!"
                                                            withAnimation(.spring()) {
                                                                showingToast = true
                                                            }
                                                        }
                                                    } catch {
                                                        await MainActor.run {
                                                            toastMessage = error.localizedDescription
                                                            withAnimation(.spring()) {
                                                                showingToast = true
                                                            }
                                                        }
                                                    }
                                                    await MainActor.run {
                                                        addingProductIds.remove(product.id)
                                                    }
                                                }
                                            }) {
                                                if addingProductIds.contains(product.id) {
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                                } else {
                                                    Image(systemName: addedProductIds.contains(product.id) ? "checkmark.circle.fill" : "plus.circle.fill")
                                                        .font(.title3)
                                                        .foregroundColor(.black)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(addingProductIds.contains(product.id))
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .listStyle(.plain)
                        }
                    }
                }
                
                // MARK: - Premium Pop-up HUD Alert (Auto-dismisses in 1.2 seconds)
                if showingToast {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                        Text(toastMessage)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.85))
                    )
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation {
                                showingToast = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Products")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
            .task {
                await productViewModel.fetchProducts()
            }
        }
    }
}

// MARK: - Subcomponents

struct RichBundleCard: View {
    let title: String
    let subtitle: String
    let imageUrl: String
    let isAdded: Bool
    let isAdding: Bool
    let onAddTap: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedImageView(urlString: imageUrl) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.1))
            }
            .frame(width: 200, height: 130)
            .clipped()
            .overlay(Color.black.opacity(isAdded ? 0.6 : 0.35))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                
                Button(action: {
                    if !isAdded && !isAdding {
                        onAddTap()
                    }
                }) {
                    HStack(spacing: 4) {
                        if isAdding {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                            Text("Adding...")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                        } else if isAdded {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                            Text("Added")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("Add Bundle +")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isAdded ? Color.gray.opacity(0.4) : Color.white)
                    .cornerRadius(4)
                }
                .disabled(isAdded || isAdding)
                .padding(.top, 4)
            }
            .padding(12)
        }
        .frame(width: 200, height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Item Row supporting native swiping (no right-side icons!)

struct RegistryItemRow: View {
    let item: RegistryItem
    let registryId: String
    let onTap: () -> Void
    let onTagUpdate: () -> Void
    
    var isFullyGifted: Bool {
        let qtyFullyGifted = item.quantityReceived >= item.quantityRequested && item.quantityRequested > 0
        let contributionFullyFunded = (item.isFullyFunded ?? false)
        return qtyFullyGifted || contributionFullyFunded
    }
    
    var body: some View {
        HStack(spacing: 14) {
            if let product = item.products {
                CachedImageView(urlString: product.imageUrl ?? "") { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.08))
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .opacity(isFullyGifted ? 0.5 : 1.0)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(product.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                        .opacity(isFullyGifted ? 0.5 : 1.0)
                    
                    Text("$\(String(format: "%.2f", product.price))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        if isFullyGifted {
                            Text("FULLY GIFTED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.gray)
                                .clipShape(Capsule())
                        } else {
                            if item.isMostWanted {
                                Text("MOST WANTED")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.black)
                                    .clipShape(Capsule())
                            }
                            
                            let isGroupGift = item.isGroupGift ?? (product.price >= 150.0)
                            if isGroupGift {
                                Text("GROUP GIFT")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    if MockRegistryService.shared.registries.first(where: { $0.id == registryId })?.isOwner == true {
                        HStack(spacing: 8) {
                            Stepper(value: Binding(
                                get: { item.quantityRequested },
                                set: { newValue in
                                    Task {
                                        do {
                                            _ = try await RegistryService.shared.updateRegistryItem(
                                                registryId: registryId,
                                                itemId: item.id,
                                                updates: ["quantity_requested": newValue]
                                            )
                                            try await MockRegistryService.shared.fetchRegistryDashboard(registryId: registryId)
                                            await MainActor.run {
                                                onTagUpdate()
                                            }
                                        } catch {
                                            print("Error updating quantity: \(error)")
                                        }
                                    }
                                }
                            ), in: 1...100) {
                                Text("Desired Qty: \(item.quantityRequested)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            .fixedSize()
                            
                            Text("| Received: \(item.quantityReceived)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    } else {
                        Text("Requested: \(item.quantityRequested) | Received: \(item.quantityReceived)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    let isGroupGift = item.isGroupGift ?? (product.price >= 150.0)
                    if isGroupGift && item.quantityRequested > 0 && !isFullyGifted {
                        let targetAmount = product.price * Double(max(1, item.quantityRequested))
                        let contributed = item.totalContributed ?? 0
                        let remaining = max(0, targetAmount - contributed)
                        Text("$\(Int(contributed)) of $\(Int(targetAmount)) funded  •  $\(Int(remaining)) left")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Tag Edit sheet

struct RegistryItemTagEditView: View {
    let registryId: String
    let item: RegistryItem
    let onComplete: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var isMostWanted = false
    @State private var isGroupGift = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Registry Settings")) {
                    Toggle("Mark as Most Wanted", isOn: $isMostWanted)
                        .font(.body)
                        .tint(.black)
                    Toggle("Enable Group Gifting (Split Contributions)", isOn: $isGroupGift)
                        .font(.body)
                        .tint(.black)
                }
            }
            .navigationTitle("Item Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            if item.isMostWanted != isMostWanted {
                                MockRegistryService.shared.toggleMostWanted(registryId: registryId, itemId: item.id)
                            }
                            let currentGroup = item.isGroupGift ?? ((item.products?.price ?? 0.0) >= 150.0)
                            if currentGroup != isGroupGift {
                                MockRegistryService.shared.toggleGroupGift(registryId: registryId, itemId: item.id)
                            }
                            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s sleep for toggles
                            try? await MockRegistryService.shared.fetchRegistryDashboard(registryId: registryId)
                            await MainActor.run {
                                onComplete()
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                }
            }
            .onAppear {
                isMostWanted = item.isMostWanted
                isGroupGift = item.isGroupGift ?? ((item.products?.price ?? 0.0) >= 150.0)
            }
        }
        .presentationDetents([.fraction(0.35)])
    }
}

// MARK: - Registry Item Contributors View

struct RegistryItemContributorsView: View {
    let item: RegistryItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if let product = item.products {
                    Section {
                        HStack(spacing: 16) {
                            CachedImageView(urlString: product.imageUrl ?? "") { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Rectangle().fill(Color.gray.opacity(0.1))
                            }
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.name)
                                    .font(.headline)
                                Text("$\(String(format: "%.2f", product.price))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Contributors")) {
                    if let contribs = item.contributions, !contribs.isEmpty {
                        ForEach(contribs) { c in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(c.contributorName)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("$\(String(format: "%.2f", c.amount))")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.secondary)
                                }
                                if let msg = c.message, !msg.isEmpty {
                                    Text("\"\(msg)\"")
                                        .font(.caption)
                                        .italic()
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        Text("No contributions yet.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Gift Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Premium Registry Share Sheet

struct RegistryShareSheetView: View {
    let registryId: String
    let fallbackCode: String
    let onNativeShareTap: (String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var copied = false
    @State private var copiedLink = false
    @State private var shareCode: String = ""
    @State private var shareUrl: String = ""

    var body: some View {
        VStack(spacing: 24) {
            // Drag Indicator
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            VStack(spacing: 8) {
                Text("Share Registry")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Send your code or link to friends and family so they can join your registry.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Share Code Display Box
            Button(action: {
                let codeToCopy = shareCode.isEmpty ? fallbackCode : shareCode
                UIPasteboard.general.string = codeToCopy
                let impact = UINotificationFeedbackGenerator()
                impact.notificationOccurred(.success)
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            }) {
                HStack(spacing: 12) {
                    Text(shareCode.isEmpty ? fallbackCode : shareCode)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .tracking(2)
                        .foregroundColor(.primary)
                    
                    Spacer()

                    Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.body)
                        .foregroundColor(copied ? .green : .primary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            if !shareUrl.isEmpty {
                VStack(spacing: 8) {
                    Text("Share Link")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: {
                        UIPasteboard.general.string = shareUrl
                        let impact = UINotificationFeedbackGenerator()
                        impact.notificationOccurred(.success)
                        withAnimation { copiedLink = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedLink = false }
                    }) {
                        HStack(spacing: 12) {
                            Text(shareUrl)
                                .font(.footnote)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()

                            Image(systemName: copiedLink ? "checkmark.circle.fill" : "link")
                                .font(.body)
                                .foregroundColor(copiedLink ? .green : .primary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1.5)
                        )
                        .padding(.horizontal, 24)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 12) {
                Text("OR SHARE TO APPS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)

                Button(action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let code = shareCode.isEmpty ? fallbackCode : shareCode
                        let textToShare = !shareUrl.isEmpty ? shareUrl : "Join my registry with code: \(code)"
                        onNativeShareTap(textToShare)
                    }
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Open iOS Sharing Options...")
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.bottom, 24)
        .presentationDetents([.fraction(0.55)])
        .presentationDragIndicator(.hidden)
        .task {
            do {
                let resp = try await RegistryService.shared.fetchShareLink(registryId: registryId)
                shareCode = resp.shareToken
                shareUrl = resp.shareUrl
            } catch {
                shareCode = fallbackCode
                shareUrl = ""
            }
        }
    }
}
