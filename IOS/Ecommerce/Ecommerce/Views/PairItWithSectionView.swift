import SwiftUI

struct PairItWithSectionView: View {
    @ObservedObject var viewModel: PairItWithViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            Text("Might We Suggest")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.leading, 8) // Reduced left padding
            
            // Horizontal ScrollView
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.recommendations) { recommendation in
                        NavigationLink(destination: ProductDetailView(product: recommendation.product)) {
                            PairItWithCardView(recommendation: recommendation)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.leading, 8)
            }
        }
        .padding(.vertical, 8)
    }
}
