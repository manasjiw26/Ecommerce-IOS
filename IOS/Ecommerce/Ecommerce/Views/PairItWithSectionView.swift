import SwiftUI

struct PairItWithSectionView: View {
    @ObservedObject var viewModel: PairItWithViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Might We Suggest")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Dynamic Contextual Subheading
                Text(viewModel.contextSubheading)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
            .padding(.leading, 8)

            if viewModel.isLoading {
                // Shimmer placeholders while first fetch is in progress
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(0..<4, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 0) {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 140, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .shimmer()

                                VStack(alignment: .leading, spacing: 4) {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 100, height: 11)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .shimmer()

                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 50, height: 11)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .shimmer()
                                }
                                .padding(.top, 8)
                                .padding(.horizontal, 2)
                            }
                            .frame(width: 140)
                        }
                    }
                    .padding(.leading, 8)
                }
            } else if viewModel.intelligenceLevel == .multiContext {
                // Grouped Recommendation Rendering (Multiple Carousels)
                let groupedRecommendations = Dictionary(grouping: viewModel.recommendations, by: { $0.product.category ?? "Other" })
                let sortedCategories = groupedRecommendations.keys.sorted()
                
                VStack(spacing: 24) {
                    ForEach(sortedCategories, id: \.self) { category in
                        if let items = groupedRecommendations[category] {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(category) Essentials")
                                    .font(.headline)
                                    .padding(.leading, 8)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(items) { recommendation in
                                            NavigationLink(destination: ProductDetailView(product: recommendation.product)) {
                                                PairItWithCardView(recommendation: recommendation)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.leading, 8)
                                }
                            }
                        }
                    }
                }
            } else {
                // Single Horizontal ScrollView
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
        }
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.35), value: viewModel.contextSubheading)
        .animation(.easeInOut(duration: 0.4), value: viewModel.recommendations)
    }
}
