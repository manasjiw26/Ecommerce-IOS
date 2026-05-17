import SwiftUI
import UIKit

struct ProductDetailView: View {
    let product: Product
    var showCloseButton: Bool = false
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var savedVM: SavedForLaterViewModel
    @ObservedObject private var recoEngine = RecommendationEngine.shared
    @ObservedObject private var authSession = AuthSession.shared
    @State private var similarProducts: [Product] = []
    @State private var isLoadingSimilar = true
    private let imageHeight: CGFloat = 340
    
    @State private var productReviews: [ProductReview] = []
    @State private var isLoadingReviews = true
    @State private var isShowingWriteReviewSheet = false
    @State private var isShowingGuestAlert = false
    @State private var isReviewsExpanded = false
    
    // Registry Add Workflow
    @State private var isShowingRegistrySheet = false
    @State private var showingToast = false
    @State private var toastMessage = ""
    
    private var averageRating: Double {
        guard !productReviews.isEmpty else { return 0.0 }
        let sum = productReviews.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(productReviews.count)
    }
    
    private var sortedReviews: [ProductReview] {
        guard let currentUser = authSession.currentUser else { return productReviews }
        let currentUserName = (currentUser.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_").lowercased()
        let currentUserEmail = currentUser.email.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_").lowercased()
        
        return productReviews.sorted { a, b in
            let aIsCurrent = (a.userId.lowercased() == currentUserName || a.userId.lowercased() == currentUserEmail)
            let bIsCurrent = (b.userId.lowercased() == currentUserName || b.userId.lowercased() == currentUserEmail)
            if aIsCurrent && !bIsCurrent {
                return true
            } else if !aIsCurrent && bIsCurrent {
                return false
            }
            return false
        }
    }
    
    private func percentage(forStars stars: Int) -> Double {
        guard !productReviews.isEmpty else { return 0.0 }
        let count = productReviews.filter { $0.rating == stars }.count
        return Double(count) / Double(productReviews.count)
    }
    
    private func shareProduct() {
        let text = "Check out this amazing product: \(product.name) on our store!"
        let url = URL(string: "https://ecommerce.example.com/products/\(product.id)") ?? URL(string: "https://ecommerce.example.com")!
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            
            let activityVC = UIActivityViewController(activityItems: [text, url], applicationActivities: nil)
            
            // iPad popover presentation compatibility
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            topVC.present(activityVC, animated: true, completion: nil)
        }
    }
    
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
                        
                        HStack(alignment: .center, spacing: 8) {
                            Text(product.name)
                                .font(.title3)
                                .fontWeight(.bold)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                            
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                shareProduct()
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    Task { await savedVM.toggleSave(product: product) }
                                }
                            }) {
                                Image(systemName: savedVM.isSaved(productId: product.id) ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(savedVM.isSaved(productId: product.id) ? .primary : .secondary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Text("$\(String(format: "%.2f", product.price))")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    // Stock indicator
                    if let stock = product.stock {
                        if stock == 0 {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("Out of Stock")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        } else if stock <= 3 {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                                Text("Only \(stock) left!")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            }
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
                    
                    // MARK: — Customer Reviews
                    reviewsSection
                    
                    // MARK: — Suggested Matches Carousel
                    if isLoadingSimilar {
                        Divider().padding(.top, 4)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.subheadline)
                                Text("You May Also Like")
                                    .font(.headline)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(0..<3) { _ in
                                        let placeholder = Rectangle()
                                            .fill(Color(.systemGray5))
                                            .frame(width: 130, height: 180)
                                        placeholder
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
                                Text("You May Also Like")
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
        .overlay(
            VStack {
                Spacer()
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
                    .padding(.bottom, 120)
                }
            }
            .animation(.spring(), value: showingToast)
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .tabBar)
        .toolbar {
            if showCloseButton {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(.secondaryLabel))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            addToCartBar
        }
        .onAppear {
            RecommendationEngine.shared.logEvent(productId: product.id, eventType: "view")
            RecommendationEngine.shared.recordView(product: product)
            productViewModel.activeProductId = product.id
            NotificationCenter.default.post(
                name: .aiDidSpotProduct,
                object: nil,
                userInfo: ["name": product.name, "id": product.id]
            )
        }
        .onDisappear {
            if productViewModel.activeProductId == product.id {
                productViewModel.activeProductId = nil
            }
        }
        .task {
            let results = await recoEngine.fetchSimilarProducts(to: product)
            await MainActor.run {
                self.similarProducts = results
                self.isLoadingSimilar = false
            }
            
            do {
                let fetchedReviews = try await APIService.shared.fetchReviews(productId: product.id)
                await MainActor.run {
                    self.productReviews = fetchedReviews
                    self.isLoadingReviews = false
                }
            } catch {
                print("Failed to fetch reviews: \(error)")
                await MainActor.run {
                    self.isLoadingReviews = false
                }
            }
        }
        .sheet(isPresented: $isShowingWriteReviewSheet) {
            WriteReviewSheet(productId: product.id) {
                Task {
                    do {
                        let updated = try await APIService.shared.fetchReviews(productId: product.id)
                        await MainActor.run {
                            self.productReviews = updated
                        }
                    } catch {
                        print("Failed to refresh reviews: \(error)")
                    }
                }
            }
        }
        .alert("Authentication Required", isPresented: $isShowingGuestAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please login first to proceed.")
        }
        .sheet(isPresented: $isShowingRegistrySheet) {
            AddToRegistrySheet(product: product) { successMsg in
                toastMessage = successMsg
                withAnimation { showingToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showingToast = false }
                }
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
                
                // Add to Registry button
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    if authSession.currentUser != nil {
                        isShowingRegistrySheet = true
                    } else {
                        isShowingGuestAlert = true
                    }
                }) {
                    ZStack {
                        if quantityInCart > 0 {
                            Image(systemName: "gift")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .transition(.scale.combined(with: .opacity))
                                .frame(width: 44, height: 44)
                        } else {
                            Text("Add to Registry")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 20)
                                .frame(height: 44)
                                .transition(.opacity)
                        }
                    }
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(22)
                }
                .buttonStyle(.plain)
                
                if quantityInCart > 0 {
                    // Counter UI (Stepper Variant)
                    HStack(spacing: 20) {
                        Button(action: {
                            let impactMed = UIImpactFeedbackGenerator(style: .medium)
                            impactMed.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                cartManager.removeFromCart(product: product)
                            }
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
                            .contentTransition(.numericText())
                        
                        Button(action: {
                            let impactMed = UIImpactFeedbackGenerator(style: .medium)
                            impactMed.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                cartManager.addToCart(product: product)
                            }
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
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    // Add to Cart Button (Standard Variant)
                    Button(action: {
                        let impactMed = UIImpactFeedbackGenerator(style: .medium)
                        impactMed.impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            cartManager.addToCart(product: product)
                        }
                    }) {
                        Image(systemName: "cart.badge.plus")
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
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemBackground))
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: quantityInCart)
    }
    
    // MARK: — Reviews Section
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider().padding(.vertical, 8)
            
            if isLoadingReviews {
                HStack {
                    Spacer()
                    ProgressView("Loading reviews...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if productReviews.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Customer Reviews")
                            .font(.headline)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: {
                            if authSession.currentUser != nil {
                                isShowingWriteReviewSheet = true
                            } else {
                                isShowingGuestAlert = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.pencil")
                                Text("Write a Review")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                    }
                    
                    Text("No reviews yet. Be the first to share your thoughts!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Customer Reviews")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.primary)
                                    .font(.caption)
                                Text(String(format: "%.1f", averageRating))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("(\(productReviews.count))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                if authSession.currentUser != nil {
                                    isShowingWriteReviewSheet = true
                                } else {
                                    isShowingGuestAlert = true
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.pencil")
                                    Text("Write a Review")
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(Capsule())
                            }
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isReviewsExpanded.toggle()
                                }
                            }) {
                                Image(systemName: isReviewsExpanded ? "chevron.up" : "chevron.right")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 32, height: 32)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    if isReviewsExpanded {
                        VStack(spacing: 6) {
                            ratingRow(stars: 5, percentage: percentage(forStars: 5))
                            ratingRow(stars: 4, percentage: percentage(forStars: 4))
                            ratingRow(stars: 3, percentage: percentage(forStars: 3))
                            ratingRow(stars: 2, percentage: percentage(forStars: 2))
                            ratingRow(stars: 1, percentage: percentage(forStars: 1))
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }
    
    // MARK: — Rating Bar Row Subview
    private func ratingRow(stars: Int, percentage: Double) -> some View {
        HStack(spacing: 8) {
            Text("\(stars) Star")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                    Capsule()
                        .fill(Color.primary)
                        .frame(width: geo.size.width * CGFloat(percentage))
                }
            }
            .frame(height: 6)
            
            Text("\(Int(percentage * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

// MARK: - Write Review Sheet
struct WriteReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let productId: Int
    let onSubmitted: () -> Void

    @State private var selectedRating: Int = 5
    @State private var reviewBody: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Rating") {
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                .font(.system(size: 28))
                                .foregroundColor(star <= selectedRating ? .orange : .gray.opacity(0.4))
                                .onTapGesture { selectedRating = star }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Your Review") {
                    TextEditor(text: $reviewBody)
                        .frame(minHeight: 100)
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Write a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        Task { await submit() }
                    }
                    .fontWeight(.semibold)
                    .disabled(reviewBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
        }
    }

    private func submit() async {
        guard let user = AuthSession.shared.currentUser else {
            errorMessage = "You must be logged in to submit a review."
            return
        }
        isSubmitting = true
        errorMessage = nil
        do {
            _ = try await APIService.shared.submitReview(
                productId: productId,
                userId: user.id,
                rating: selectedRating,
                body: reviewBody.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            await MainActor.run {
                onSubmitted()
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}

// MARK: - Add To Registry Sheet
struct AddToRegistrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let product: Product
    let onSuccess: (String) -> Void

    @State private var registries: [MockRegistryExtended] = []
    @State private var isLoading = true
    @State private var isAdding: String? = nil  // registry id being added
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading registries…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if registries.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "gift")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No active registries")
                            .font(.title3).fontWeight(.semibold)
                        Text("Create a registry first from the Registry tab.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(registries) { registry in
                        Button {
                            Task { await addToRegistry(registry) }
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(registry.type.capitalized)
                                        .font(.subheadline).fontWeight(.semibold)
                                    Text(registry.date)
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                if isAdding == registry.id {
                                    ProgressView()
                                } else {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(isAdding != nil)
                    }
                }
            }
            .navigationTitle("Add to Registry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadRegistries() }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func loadRegistries() async {
        do {
            try await MockRegistryService.shared.fetchRegistriesFromBackend()
        } catch {
            // Non-fatal: show whatever registries loaded
        }
        await MainActor.run {
            registries = MockRegistryService.shared.registries
            isLoading = false
        }
    }

    private func addToRegistry(_ registry: MockRegistryExtended) async {
        isAdding = registry.id
        do {
            try await MockRegistryService.shared.addProductToRegistry(registryId: registry.id, product: product)
            await MainActor.run {
                onSuccess("Added to \(registry.type.capitalized) registry!")
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isAdding = nil
            }
        }
    }
}

