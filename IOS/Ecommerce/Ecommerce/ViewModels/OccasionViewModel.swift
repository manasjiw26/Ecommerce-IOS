import Foundation
import Combine
import CoreML

@MainActor
class OccasionViewModel: ObservableObject {
    @Published var currentOccasion: Occasion? = nil
    
    init() {}
    
    func detectOccasion(from items: [CartItem]) {
        guard !items.isEmpty else {
            currentOccasion = nil
            return
        }
        
        // 1. Prepare Features for Core ML
        let calendar = Calendar.current
        let month = Double(calendar.component(.month, from: Date()))
        
        // Aggregate tags and find top category
        var tagCounts: [String: Int] = [:]
        var categoryCounts: [String: Int] = [:]
        var totalPrice: Double = 0
        var allTags: Set<String> = []
        for item in items {
            totalPrice += item.product.price * Double(item.quantity)
            let category = item.product.category ?? "general"
            categoryCounts[category, default: 0] += item.quantity
            
            // Collect raw tags exactly as they are in your database
            if let tags = item.product.tags {
                for rawTag in tags {
                    let tag = rawTag.lowercased().trimmingCharacters(in: .whitespaces)
                    allTags.insert(tag)
                    tagCounts[tag, default: 0] += item.quantity
                }
            }

            // If tags are missing (common if backend join omits them), infer a few high-signal tags from name/category.
            if item.product.tags == nil || item.product.tags?.isEmpty == true {
                let name = item.product.name.lowercased()
                let cat  = (item.product.category ?? "").lowercased()
                let hay  = "\(name) \(cat)"

                if hay.contains("glass") || hay.contains("wine") || hay.contains("platter") || hay.contains("hosting") {
                    allTags.insert("hosting")
                    tagCounts["hosting", default: 0] += item.quantity
                }
                if hay.contains("candle") || hay.contains("decor") || hay.contains("vase") || hay.contains("scent") || hay.contains("pillow") {
                    allTags.insert("home_sanctuary")
                    tagCounts["home_sanctuary", default: 0] += item.quantity
                }
                if hay.contains("pan") || hay.contains("pot") || hay.contains("chef") || hay.contains("knife") || hay.contains("oven") {
                    allTags.insert("culinary")
                    tagCounts["culinary", default: 0] += item.quantity
                }
            }
        }
        
        // Create the blob: 6 tags max, space-separated, natural order
        let tagsBlob = allTags.prefix(6).joined(separator: " ")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        // Prefer quantity-weighted count (a cart with 1 item x10 should not look like "1").
        let itemCount = Int64(items.reduce(0) { $0 + $1.quantity })
        
        let denom = max(1, items.reduce(0) { $0 + $1.quantity })
        let avgPrice = totalPrice / Double(denom)
        let priceTier: String
        if avgPrice < 30 { priceTier = "budget" }
        else if avgPrice < 100 { priceTier = "mid-range" }
        else { priceTier = "luxury" }
        
        // 2. Run Prediction using Core ML
        do {
            let config = MLModelConfiguration()
            let model = try updatedModel(configuration: config)
            
            // Ensure we never send an empty string to the model
            let safeTags = tagsBlob.isEmpty ? "none" : tagsBlob
            
            print("--- Occasion Prediction (New Model) ---")
            print("Month: \(Int64(month))")
            print("Tags Blob: [\(safeTags)]")
            print("Price Tier: [\(priceTier)]")
            print("Item Count: \(itemCount)")
            
            let input = updatedModelInput(
                month: Int64(month),
                item_tags_blob: safeTags,
                price_tier: priceTier,
                item_count: itemCount
            )
            
            let prediction = try model.prediction(input: input)
            let predictedOccasion = prediction.occasion_label
            
            // --- ADVANCED DEBUG: PROBABILITIES ---
            print("📊 AI Confidence Scores:")
            for (label, prob) in prediction.occasion_labelProbability {
                let percentage = String(format: "%.1f%%", prob * 100)
                print("   [\(label)]: \(percentage)")
            }
            // -------------------------------------
            
            print("✅ Final Prediction: \(predictedOccasion)")
            print("---------------------------------")
            
            // 3. Update UI State and Trigger Recommendations
            updateOccasionState(for: predictedOccasion)
            if currentOccasion == nil {
                // If model returns an unexpected label, degrade gracefully.
                fallbackDetection(tagCounts: tagCounts)
            }
            
        } catch {
            print("❌ Core ML Prediction Error: \(error.localizedDescription)")
            print("🔄 Triggering FALLBACK Logic...")
            // Fallback to simple tag-based logic if model fails
            fallbackDetection(tagCounts: tagCounts)
        }
    }
    
    private func updateOccasionState(for label: String) {
        // Map the predicted label to our UI model
        let lowercaseLabel = label.lowercased()
        
        if lowercaseLabel.contains("hosting") {
            currentOccasion = Occasion(
                title: "SMART OCCASION",
                subtitle: "Hosting Night",
                description: "Perfect evening essentials.",
                tag: "hosting",
                backgroundImageUrl: "hosting_night_bg",
                isLocalAsset: true
            )
        } else if lowercaseLabel.contains("sanctuary") {
            currentOccasion = Occasion(
                title: "SMART OCCASION",
                subtitle: "Home Sanctuary",
                description: "Your cozy corner.",
                tag: "home_sanctuary",
                backgroundImageUrl: "home_sanctuary_bg",
                isLocalAsset: true
            )
        } else if lowercaseLabel.contains("culinary") {
            currentOccasion = Occasion(
                title: "SMART OCCASION",
                subtitle: "Culinary Masterclass",
                description: "Professional home tools.",
                tag: "culinary",
                backgroundImageUrl: "culinary_bg",
                isLocalAsset: true
            )
        } else {
            currentOccasion = nil
        }
        
        // If an occasion was detected, trigger the Recommendation Engine
        if let occasion = currentOccasion {
            RecommendationEngine.shared.searchProducts(query: occasion.tag)
        }
    }
    
    private func fallbackDetection(tagCounts: [String: Int]) {
        if let (topTag, _) = tagCounts.max(by: { $0.value < $1.value }) {
            updateOccasionState(for: topTag)
        } else {
            currentOccasion = nil
        }
    }
}
