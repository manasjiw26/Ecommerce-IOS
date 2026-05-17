import SwiftUI

struct RegistryGuestLandingView: View {
    let registry: MockRegistryExtended
    
    @State private var showingCheckoutSheet = false
    @State private var showingSurpriseSelector = false
    @State private var selectedItem: RegistryItem?
    @State private var isGroupContribution = false
    @State private var items: [RegistryItem] = []
    @State private var selectedProductForDetail: Product? = nil
    
    // Filtering States
    @State private var selectedCollection = "All"
    @State private var selectedPriceRange = "All"
    @State private var showOnlyAvailable = false
    
    @Environment(\.dismiss) var dismiss
    
    var daysRemainingString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        if let targetDate = formatter.date(from: registry.date) {
            let diff = Calendar.current.dateComponents([.day], from: Date(), to: targetDate)
            if let days = diff.day {
                if days > 0 {
                    return "\(days) Days to go"
                } else if days == 0 {
                    return "Today is the event!"
                } else {
                    return "Celebrated!"
                }
            }
        }
        return "Happening soon"
    }
    
    // Filtered Items List
    var filteredItems: [RegistryItem] {
        items.filter { item in
            guard let product = item.products else { return false }
            
            // 1. Collection Filtering
            let categoryLower = (product.category ?? "").lowercased()
            switch selectedCollection {
            case "Most Wanted":
                if !item.isMostWanted { return false }
            case "Group Gifts":
                let isGroupGift = item.isGroupGift ?? (product.price >= 150.0)
                if !isGroupGift { return false }
            case "Kitchen":
                if !categoryLower.contains("kitchen") && !categoryLower.contains("cook") { return false }
            case "Dining":
                if !categoryLower.contains("dining") && !categoryLower.contains("cutlery") && !categoryLower.contains("glass") { return false }
            case "Decor":
                if !categoryLower.contains("decor") && !categoryLower.contains("light") { return false }
            default:
                break
            }
            
            // 2. Price Range Filtering
            switch selectedPriceRange {
            case "Under $50":
                if product.price >= 50.0 { return false }
            case "$50 - $100":
                if product.price < 50.0 || product.price > 100.0 { return false }
            case "$100 - $200":
                if product.price < 100.0 || product.price > 200.0 { return false }
            case "$200+":
                if product.price < 200.0 { return false }
            default:
                break
            }
            
            // 3. Availability Filtering
            if showOnlyAvailable {
                if item.quantityReceived >= item.quantityRequested && item.quantityRequested > 0 {
                    return false
                }
            }
            
            return true
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Premium Hero Section
                ZStack(alignment: .bottomLeading) {
                    CachedImageView(urlString: registry.bannerImageUrl) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.1))
                    }
                    .frame(height: 240)
                    .clipped()
                    .overlay(Color.black.opacity(0.45))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(daysRemainingString.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white)
                                .cornerRadius(3)
                        }
                        
                        Text(registry.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(registry.eventStory)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                            .padding(.top, 2)
                        
                        HStack(spacing: 12) {
                            Text(registry.date)
                            Text("•")
                            Text(registry.location)
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(20)
                }
                
                // MARK: - Surprise Gift Browse Card
                Button(action: {
                    showingSurpriseSelector = true
                }) {
                    ZStack(alignment: .trailing) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Gift a Surprise Item")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Browse products to send a special surprise gift not on their list.")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                        .padding(20)
                        
                        Image(systemName: "gift.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.15))
                            .padding(.trailing, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
                
                // MARK: - Typographic Stat Box (No graphs/progress bars!)
                let fulfilledCount = items.filter { $0.quantityReceived >= $0.quantityRequested && $0.quantityRequested > 0 }.count
                let remainingCount = items.filter { $0.quantityReceived < $0.quantityRequested || $0.quantityRequested == 0 }.count
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WISHES FULFILLED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .kerning(1.2)
                        Text("\(fulfilledCount)")
                            .font(.system(size: 28, weight: .thin, design: .serif))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 1, height: 40)
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GIFTS REMAINING")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .kerning(1.2)
                        Text("\(remainingCount)")
                            .font(.system(size: 28, weight: .thin, design: .serif))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                
                // MARK: - Dropdown Filter & Collections
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Registry Collections")
                            .font(.headline)
                        
                        Spacer()
                        
                        // Native iOS Dropdown Menu
                        Menu {
                            Section(header: Text("Price Filter")) {
                                Button("Price: All") { selectedPriceRange = "All" }
                                Button("Price: Under $50") { selectedPriceRange = "Under $50" }
                                Button("Price: $50 - $100") { selectedPriceRange = "$50 - $100" }
                                Button("Price: $100 - $200") { selectedPriceRange = "$100 - $200" }
                                Button("Price: $200+") { selectedPriceRange = "$200+" }
                            }
                            
                            Section {
                                Button(showOnlyAvailable ? "✓ Show Available Only" : "Show Available Only") {
                                    showOnlyAvailable.toggle()
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(6)
                                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Collections Horizontal Scroll
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(["All", "Most Wanted", "Group Gifts", "Kitchen", "Dining", "Decor"], id: \.self) { collection in
                                Button(action: { selectedCollection = collection }) {
                                    Text(collection)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(selectedCollection == collection ? .white : .primary)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 14)
                                        .background(selectedCollection == collection ? Color.black : Color(UIColor.systemGray6))
                                        .cornerRadius(20)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // MARK: - Registry Items List
                VStack(alignment: .leading, spacing: 16) {
                    let standardItems = filteredItems.filter { $0.quantityRequested > 0 }
                    let surpriseItems = filteredItems.filter { $0.quantityRequested == 0 }
                    
                    Text("\(standardItems.count + surpriseItems.count) Items Found")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                    
                    if standardItems.isEmpty && surpriseItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "giftcard")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No items found matching filters.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    } else {
                        // Standard Requested Items List
                        if !standardItems.isEmpty {
                            ForEach(standardItems) { item in
                                GuestProductCard(item: item, onTap: {
                                    if let prod = item.products {
                                        selectedProductForDetail = prod
                                    }
                                }, onGiftTap: {
                                    selectedItem = item
                                    isGroupContribution = false
                                    showingCheckoutSheet = true
                                }, onContributeTap: {
                                    selectedItem = item
                                    isGroupContribution = true
                                    showingCheckoutSheet = true
                                })
                                Divider().padding(.horizontal, 20)
                            }
                        }
                        
                        // Surprise Gifts from Guests (Convenient bottom layout)
                        if !surpriseItems.isEmpty {
                            Text("Surprise Gifts Added by Guests")
                                .font(.headline)
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                            
                            ForEach(surpriseItems) { item in
                                GuestProductCard(item: item, onTap: {
                                    if let prod = item.products {
                                        selectedProductForDetail = prod
                                    }
                                }, onGiftTap: {
                                    selectedItem = item
                                    isGroupContribution = false
                                    showingCheckoutSheet = true
                                }, onContributeTap: {
                                    selectedItem = item
                                    isGroupContribution = true
                                    showingCheckoutSheet = true
                                })
                                Divider().padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .onAppear {
            Task {
                try? await MockRegistryService.shared.fetchRegistryDashboard(registryId: registry.id)
                await MainActor.run {
                    items = MockRegistryService.shared.registryItems[registry.id] ?? []
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.bold)
                .foregroundColor(.primary)
            }
        }
        .sheet(isPresented: $showingCheckoutSheet) {
            if let item = selectedItem {
                GuestCheckoutSheet(
                    item: item,
                    registry: registry,
                    isGroupContribution: isGroupContribution
                ) {
                    Task {
                        try? await MockRegistryService.shared.fetchRegistryDashboard(registryId: registry.id)
                        await MainActor.run {
                            items = MockRegistryService.shared.registryItems[registry.id] ?? []
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSurpriseSelector) {
            GuestSurpriseGiftSelectorView(registryId: registry.id) { selectedProduct in
                Task {
                    MockRegistryService.shared.addAlternativeGift(registryId: registry.id, product: selectedProduct)
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s for db insert
                    try? await MockRegistryService.shared.fetchRegistryDashboard(registryId: registry.id)
                    await MainActor.run {
                        items = MockRegistryService.shared.registryItems[registry.id] ?? []
                    }
                }
            }
        }
        .sheet(item: $selectedProductForDetail) { product in
            NavigationStack {
                ProductDetailView(product: product)
            }
        }
    }
}

// MARK: - Guest Surprise Gift Selector Sheet

struct GuestSurpriseGiftSelectorView: View {
    let registryId: String
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var productViewModel = ProductViewModel()
    @State private var searchQuery = ""
    
    let onSelect: (Product) -> Void
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search catalog for surprise gift...", text: $searchQuery)
                        .font(.body)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                if productViewModel.isLoading {
                    ProgressView().padding(.top, 40)
                } else {
                    List {
                        let initialProducts = searchQuery.isEmpty ? RecommendationEngine.shared.recommendedProducts : productViewModel.products
                        let filtered = initialProducts.filter {
                            searchQuery.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchQuery) || ($0.category ?? "").localizedCaseInsensitiveContains(searchQuery)
                        }
                        
                        Section(header: Text(searchQuery.isEmpty ? "Suggestions" : "Results").font(.caption).fontWeight(.bold).foregroundColor(.secondary)) {
                            ForEach(filtered) { product in
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
                                        onSelect(product)
                                        dismiss()
                                    }) {
                                        Text("Select")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .background(Color.black)
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select Surprise Gift")
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

// MARK: - Guest Product Card Component (Monochrome, No Blue)

struct GuestProductCard: View {
    let item: RegistryItem
    let onTap: () -> Void
    let onGiftTap: () -> Void
    let onContributeTap: () -> Void
    
    var isFullyGifted: Bool {
        item.quantityReceived >= item.quantityRequested && item.quantityRequested > 0
    }
    
    var isGroupGift: Bool {
        guard let product = item.products else { return false }
        return item.isGroupGift ?? (product.price >= 150.0)
    }
    
    // Mock contribution progress (e.g. deterministic based on product ID)
    var contributionProgress: Double {
        return Double((item.productId * 7) % 75) / 100.0
    }
    
    var contributedAmount: Double {
        guard let product = item.products else { return 0 }
        return product.price * contributionProgress
    }
    
    var remainingAmount: Double {
        guard let product = item.products else { return 0 }
        return product.price - contributedAmount
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let product = item.products {
                HStack(alignment: .center, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        CachedImageView(urlString: product.imageUrl ?? "") { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.1))
                        }
                        .frame(width: 90, height: 90)
                        .cornerRadius(8)
                        .clipped()
                        .opacity(isFullyGifted ? 0.4 : 1.0)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                if isFullyGifted {
                                    Text("FULLY GIFTED")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.gray)
                                        .cornerRadius(2)
                                } else {
                                    if item.isMostWanted {
                                        Text("MOST WANTED")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.black)
                                            .cornerRadius(2)
                                    }
                                    
                                    if isGroupGift {
                                        Text("GROUP GIFT")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.black.opacity(0.6))
                                            .cornerRadius(2)
                                    }
                                }
                                
                                Spacer()
                            }
                            
                            Text(product.name)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                                .opacity(isFullyGifted ? 0.4 : 1.0)
                            
                            Text("$\(String(format: "%.2f", product.price))")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .opacity(isFullyGifted ? 0.4 : 1.0)
                            
                            // Availability status
                            if item.quantityRequested == 0 {
                                Text("Surprise Gift")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(item.quantityReceived)/\(item.quantityRequested) Gifted")
                                    .font(.caption2)
                                    .foregroundColor(isFullyGifted ? .gray : .secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }
                
                
                // Group Gifting Typographic Text (No progress bars!)
                if isGroupGift && item.quantityRequested > 0 && !isFullyGifted {
                    HStack {
                        Image(systemName: "square.and.pencil")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("WISH CONTRIBUTION: $\(Int(contributedAmount)) of $\(Int(product.price)) funded  •  $\(Int(remainingAmount)) remaining")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // CTA Action Buttons (Monochrome, Disabled if gifted)
                HStack(spacing: 12) {
                    if isFullyGifted {
                        Text("WISH GRANTED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(6)
                    } else {
                        if isGroupGift && item.quantityRequested > 0 {
                            Button(action: onContributeTap) {
                                Text("Contribute Any Amount")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: onGiftTap) {
                            Text(isGroupGift ? "Gift Full Amount" : (item.quantityRequested == 0 ? "Gift This Surprise" : "Gift This Item"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(isGroupGift ? .primary : .white)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(isGroupGift ? Color(UIColor.systemGray6) : Color.black)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.primary.opacity(isGroupGift ? 0.1 : 0), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }
}

// MARK: - Guest Checkout Sheet

struct GuestCheckoutSheet: View {
    let item: RegistryItem
    let registry: MockRegistryExtended
    let isGroupContribution: Bool
    let onCompletion: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    @State private var guestName = ""
    @State private var giftAnonymously = false
    @State private var shipDirectly = true
    @State private var personalMessage = ""
    @State private var contributionAmountString = ""
    @State private var showingPaymentWebView = false
    
    var finalAmount: Double {
        if isGroupContribution {
            return Double(contributionAmountString) ?? 50.0
        } else {
            return item.products?.price ?? 0.0
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if showingPaymentWebView {
                    RazorpayWebView(
                        amount: finalAmount,
                        razorpayKey: Config.razorpayKey,
                        onPaymentSuccess: { pid in
                            Task {
                                do {
                                    if isGroupContribution {
                                        _ = try await RegistryService.shared.contributeToGroupGift(
                                            registryId: registry.id,
                                            itemId: item.id,
                                            contributorName: giftAnonymously ? "Anonymous Guest" : (guestName.isEmpty ? "Guest" : guestName),
                                            amount: finalAmount,
                                            message: personalMessage.isEmpty ? nil : personalMessage
                                        )
                                    } else if item.quantityRequested == 0 {
                                        _ = try await RegistryService.shared.addAlternativeGift(
                                            registryId: registry.id,
                                            productId: item.productId
                                        )
                                    } else {
                                        _ = try await RegistryService.shared.updateRegistryItem(
                                            registryId: registry.id,
                                            itemId: item.id,
                                            updates: ["quantity_received": item.quantityReceived + 1]
                                        )
                                    }
                                    
                                    try? await MockRegistryService.shared.fetchRegistryDashboard(registryId: registry.id)
                                    
                                    await MainActor.run {
                                        onCompletion()
                                        dismiss()
                                    }
                                } catch {
                                    print("Error recording gift purchase: \(error)")
                                    await MainActor.run {
                                        onCompletion()
                                        dismiss()
                                    }
                                }
                            }
                        },
                        onPaymentError: { err in
                            print("Guest Gifting Payment Error: \(err)")
                            showingPaymentWebView = false
                        }
                    )
                } else {
                    Form {
                        Section(header: Text("Gifter Information")) {
                            if !giftAnonymously {
                                TextField("Your Name", text: $guestName)
                                    .font(.body)
                            }
                            
                            Toggle("Gift Anonymously", isOn: $giftAnonymously)
                                .font(.body)
                                .tint(.black)
                        }
                        
                        if isGroupContribution {
                            Section(header: Text("Contribution Amount")) {
                                HStack {
                                    Text("$")
                                        .fontWeight(.bold)
                                    TextField("Amount", text: $contributionAmountString)
                                        .keyboardType(.decimalPad)
                                        .font(.body)
                                }
                                
                                HStack(spacing: 8) {
                                    ForEach(["25", "50", "100", "200"], id: \.self) { amt in
                                        Button(action: { contributionAmountString = amt }) {
                                            Text("$\(amt)")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(contributionAmountString == amt ? .white : .primary)
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 12)
                                                .background(contributionAmountString == amt ? Color.black : Color(UIColor.systemGray6))
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        Section(header: Text("Delivery Preference")) {
                            Toggle("Ship Directly to Registrant", isOn: $shipDirectly)
                                .font(.body)
                                .tint(.black)
                            
                            if shipDirectly {
                                Text("Registrant's address is hidden for privacy. We will ship directly to their registered delivery address.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Section(header: Text("Personal Greeting")) {
                            TextField("Leave a congratulatory note...", text: $personalMessage)
                                .font(.body)
                        }
                    }
                    
                    Button(action: {
                        showingPaymentWebView = true
                    }) {
                        Text("Proceed to Secure Payment")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(8)
                            .padding()
                    }
                    .disabled(isGroupContribution && (Double(contributionAmountString) ?? 0.0) <= 0)
                }
            }
            .navigationTitle(isGroupContribution ? "Contribute to Gift" : "Gift Registry Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
            .onAppear {
                if isGroupContribution {
                    contributionAmountString = "50"
                }
            }
        }
    }
}
