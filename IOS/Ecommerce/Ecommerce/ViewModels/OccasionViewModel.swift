import Foundation
import Combine

@MainActor
class OccasionViewModel: ObservableObject {
    @Published var currentOccasion: Occasion? = nil
    
    init() {}
    
    func detectOccasion(from items: [CartItem]) {
        guard !items.isEmpty else {
            currentOccasion = nil
            return
        }
        
        // Count tags
        var tagCounts: [String: Int] = [:]
        for item in items {
            if let tag = item.product.itemTag {
                tagCounts[tag, default: 0] += item.quantity
            }
        }
        
        // Rough calculation: Trigger occasion if 2+ items match or if it's the majority
        if let (topTag, count) = tagCounts.max(by: { $0.value < $1.value }), count >= 1 {
            switch topTag {
            case "hosting":
                currentOccasion = Occasion(
                    title: "SMART OCCASION",
                    subtitle: "Hosting Night",
                    description: "Perfect evening essentials.",
                    tag: "hosting",
                    backgroundImageUrl: "hosting_night_bg",
                    isLocalAsset: true
                )
            case "home_sanctuary":
                currentOccasion = Occasion(
                    title: "SMART OCCASION",
                    subtitle: "Home Sanctuary",
                    description: "Your cozy corner.",
                    tag: "home_sanctuary",
                    backgroundImageUrl: "home_sanctuary_bg",
                    isLocalAsset: true
                )
            case "culinary":
                currentOccasion = Occasion(
                    title: "SMART OCCASION",
                    subtitle: "Culinary Masterclass",
                    description: "Professional home tools.",
                    tag: "culinary",
                    backgroundImageUrl: "culinary_bg",
                    isLocalAsset: true
                )
            default:
                currentOccasion = nil
            }
        } else {
            // Fallback/Bug condition: hide card if no strong occasion detected
            currentOccasion = nil
        }
    }
    
    // Placeholder for future Gemini API integration
    func fetchOccasionFromGemini() async {
        let apiKey = Config.geminiAPIKey
        guard apiKey != "YOUR_GEMINI_API_KEY_HERE" else { 
            print("Gemini API Key missing")
            return 
        }
        
        // Future implementation for actual model integration
        // 1. Prepare cart context (item names, categories)
        // 2. Call Gemini API
        // 3. Update currentOccasion based on AI response
    }
}
