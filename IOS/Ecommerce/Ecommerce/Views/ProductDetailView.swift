import SwiftUI
import UIKit

struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var productViewModel: ProductViewModel
    @ObservedObject private var recoEngine = RecommendationEngine.shared
    @ObservedObject private var authSession = AuthSession.shared
    @State private var similarProducts: [Product] = []
    @State private var isLoadingSimilar = true
    @State private var isSaved = false
    private let imageHeight: CGFloat = 340
    
    @State private var productReviews: [ProductReview] = []
    @State private var isLoadingReviews = true
    @State private var isShowingWriteReviewSheet = false
    @State private var isShowingGuestAlert = false
    @State private var isReviewsExpanded = false
    
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
                                    .frame(width: 40, height: 40)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isSaved.toggle()
                                }
                            }) {
                                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(isSaved ? .primary : .secondary)
                                    .frame(width: 40, height: 40)
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
                    
                    // MARK: — Suggested Matches Carousel (Moved below Customer Reviews)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            addToCartBar
        }
        .onAppear {
            RecommendationEngine.shared.logEvent(productId: product.id, eventType: "view")
            RecommendationEngine.shared.recordView(product: product)
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
            
            // Load reviews dynamically from Supabase via Express API
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
            Text("Please login first to write a review.")
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
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Customer Reviews")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        if isReviewsExpanded {
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
                    // Rating Breakdown Bars
                    VStack(spacing: 6) {
                        ratingRow(stars: 5, percentage: percentage(forStars: 5))
                        ratingRow(stars: 4, percentage: percentage(forStars: 4))
                        ratingRow(stars: 3, percentage: percentage(forStars: 3))
                        ratingRow(stars: 2, percentage: percentage(forStars: 2))
                        ratingRow(stars: 1, percentage: percentage(forStars: 1))
                    }
                    .padding(.vertical, 8)
                    
                    // Individual Review Cards
                    VStack(spacing: 14) {
                        ForEach(sortedReviews) { review in
                            let displayName = review.userId.replacingOccurrences(of: "_", with: " ").capitalized
                            let relativeDate: String = {
                                if let dateStr = review.createdAt {
                                    let formatter = ISO8601DateFormatter()
                                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                    if let date = formatter.date(from: dateStr) ?? ISO8601DateFormatter().date(from: dateStr) {
                                        let relativeFormatter = RelativeDateTimeFormatter()
                                        relativeFormatter.unitsStyle = .full
                                        return relativeFormatter.localizedString(for: date, relativeTo: Date())
                                    }
                                }
                                return "recently"
                            }()
                            
                            let isOwnReview: Bool = {
                                guard let currentUser = authSession.currentUser else { return false }
                                let currentUserName = (currentUser.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_").lowercased()
                                let currentUserEmail = currentUser.email.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_").lowercased()
                                return review.userId.lowercased() == currentUserName || review.userId.lowercased() == currentUserEmail
                            }()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    // User Initials Avatar
                                    Text(String(displayName.prefix(2)))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(Color.primary.opacity(0.8))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(displayName)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            
                                            Image(systemName: "checkmark.seal.fill")
                                                .foregroundColor(.secondary)
                                                .font(.caption2)
                                        }
                                        
                                        Text(relativeDate)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Delete Review Button (Only if it's the user's own review)
                                    if isOwnReview {
                                        Button(action: {
                                            Task {
                                                do {
                                                    try await APIService.shared.deleteReview(reviewId: review.id)
                                                    let updated = try await APIService.shared.fetchReviews(productId: product.id)
                                                    await MainActor.run {
                                                        self.productReviews = updated
                                                    }
                                                } catch {
                                                    print("Failed to delete review: \(error)")
                                                }
                                            }
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .padding(4)
                                        }
                                        .padding(.trailing, 4)
                                    }
                                    
                                    // Stars
                                    HStack(spacing: 2) {
                                        ForEach(1...5, id: \.self) { star in
                                            Image(systemName: star <= review.rating ? "star.fill" : "star")
                                                .font(.caption2)
                                                .foregroundColor(star <= review.rating ? .primary : Color(UIColor.systemGray4))
                                        }
                                    }
                                }
                                
                                if let bodyText = review.body {
                                    Text(bodyText)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(14)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
    }
    
    private func ratingRow(stars: Int, percentage: Double) -> some View {
        HStack(spacing: 8) {
            Text("\(stars)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 8)
            
            Image(systemName: "star.fill")
                .foregroundColor(.secondary)
                .font(.caption2)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary)
                        .frame(width: geo.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)
            
            Text("\(Int(percentage * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

// MARK: — Review Models
struct ProductReview: Codable, Identifiable {
    let id: String
    let productId: Int
    let userId: String
    let rating: Int
    let body: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case productId = "product_id"
        case userId = "user_id"
        case rating
        case body
        case createdAt = "created_at"
    }
}

struct WriteReviewSheet: View {
    let productId: Int
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var authSession = AuthSession.shared
    @State private var rating: Int = 5
    @State private var reviewBody: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    
    var onSubmissionSuccess: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                if let currentUser = authSession.currentUser {
                    Section(header: Text("Posting As").font(.caption).foregroundColor(.secondary)) {
                        HStack(spacing: 8) {
                            Text(currentUser.name ?? currentUser.email)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("Logged In")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(UIColor.systemGray5))
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Section(header: Text("Rating").font(.caption).foregroundColor(.secondary)) {
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundColor(star <= rating ? .primary : Color(UIColor.systemGray4))
                                .onTapGesture {
                                    rating = star
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Review Details").font(.caption).foregroundColor(.secondary)) {
                    ZStack(alignment: .topLeading) {
                        if reviewBody.isEmpty {
                            Text("Share your thoughts about this product...")
                                .foregroundColor(Color(UIColor.placeholderText))
                                .font(.subheadline)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $reviewBody)
                            .frame(minHeight: 120)
                            .font(.subheadline)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Write a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Submit") {
                            submitReview()
                        }
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .disabled(reviewBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
    
    private func submitReview() {
        guard let currentUser = authSession.currentUser else {
            errorMessage = "Please login to post a review."
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        let rawName = currentUser.name ?? currentUser.email
        let sanitizedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
        
        Task {
            do {
                _ = try await APIService.shared.submitReview(
                    productId: productId,
                    userId: sanitizedName,
                    rating: rating,
                    body: reviewBody
                )
                await MainActor.run {
                    isSubmitting = false
                    onSubmissionSuccess()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSubmitting = false
                }
            }
        }
    }
}
