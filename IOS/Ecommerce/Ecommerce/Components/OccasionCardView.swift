import SwiftUI

struct OccasionCardView: View {
    let occasion: Occasion
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image with Gradient
            if occasion.isLocalAsset, let assetName = occasion.backgroundImageUrl {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()
            } else if let urlString = occasion.backgroundImageUrl {
                CachedImageView(urlString: urlString) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .shimmer()
                }
            }
            
            // Dark Gradient Overlay - More intense to ensure text visibility
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.4), .black.opacity(0.85)]),
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Content
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(occasion.subtitle)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(occasion.description)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("View Suggestions")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(Capsule())
            }
            .padding(16)
            
            // Top-Left Planning Badge
            VStack {
                HStack {
                    Text(occasion.title)
                        .font(.system(size: 10.5, weight: .bold))
                        .kerning(1.2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.75))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    Spacer()
                }
                Spacer()
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}
