import Foundation
import Combine
import SwiftUI

@MainActor
class ProductDetailViewModel: ObservableObject {
    let product: Product
    
    @Published var similarProducts: [Product] = []
    @Published var isLoadingSimilar = true
    
    @Published var productReviews: [ProductReview] = []
    @Published var isLoadingReviews = true
    
    @Published var isShowingWriteReviewSheet = false
    @Published var isShowingGuestAlert = false
    @Published var isReviewsExpanded = false
    
    @Published var isShowingRegistrySheet = false
    @Published var showingToast = false
    @Published var toastMessage = ""
    
    init(product: Product) {
        self.product = product
    }
    
    func fetchInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchSimilarProducts() }
            group.addTask { await self.fetchReviews() }
        }
    }
    
    func fetchSimilarProducts() async {
        isLoadingSimilar = true
        let results = await RecommendationEngine.shared.fetchSimilarProducts(to: product)
        self.similarProducts = results
        isLoadingSimilar = false
    }
    
    func fetchReviews() async {
        isLoadingReviews = true
        do {
            self.productReviews = try await APIService.shared.fetchReviews(productId: product.id)
        } catch {
            print("Failed to fetch reviews: \(error)")
        }
        isLoadingReviews = false
    }
    
    func submitReview(rating: Int, comment: String, onComplete: @escaping () -> Void) {
        guard let currentUser = AuthSession.shared.currentUser else { return }
        
        Task {
            do {
                _ = try await APIService.shared.submitReview(
                    productId: product.id,
                    userId: currentUser.id, // Or name/email depending on schema
                    rating: rating,
                    body: comment
                )
                await fetchReviews()
                onComplete()
            } catch {
                showToast("Failed to submit review: \(error.localizedDescription)")
            }
        }
    }
    
    func showToast(_ message: String) {
        toastMessage = message
        withAnimation { showingToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { self.showingToast = false }
        }
    }
    
    var averageRating: Double {
        guard !productReviews.isEmpty else { return 0.0 }
        let sum = productReviews.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(productReviews.count)
    }
    
    func percentage(forStars stars: Int) -> Double {
        guard !productReviews.isEmpty else { return 0.0 }
        let count = productReviews.filter { $0.rating == stars }.count
        return Double(count) / Double(productReviews.count)
    }
    
    var sortedReviews: [ProductReview] {
        guard let currentUser = AuthSession.shared.currentUser else { return productReviews }
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
    
    func shareProduct(sourceView: UIView?) {
        let text = "Check out this amazing product: \(product.name) on ShopEase!"
        let url = URL(string: "https://ecommerce-ios.onrender.com/products/\(product.id)") ?? URL(string: "https://ecommerce-ios.onrender.com")!
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            
            let activityVC = UIActivityViewController(activityItems: [text, url], applicationActivities: nil)
            
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = sourceView ?? topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            topVC.present(activityVC, animated: true, completion: nil)
        }
    }
}
