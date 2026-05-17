import SwiftUI

struct PairItWithSectionView: View {
    @ObservedObject var viewModel: PairItWithViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Might We Suggest")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                // Dynamic Contextual Subheading
                Text(viewModel.contextSubheading)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .transition(.opacity)
            }
            .padding(.leading, 4)

            if viewModel.isLoading {
                // Shimmer placeholders while first fetch is in progress
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(0..<4, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 0) {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 146, height: 146)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                            .frame(width: 146)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                }
            } else {
                // Single Horizontal ScrollView of Individual White Cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(viewModel.recommendations) { recommendation in
                            NavigationLink(destination: ProductDetailView(product: recommendation.product)) {
                                PairItWithCardView(recommendation: recommendation)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.35), value: viewModel.contextSubheading)
        .animation(.easeInOut(duration: 0.4), value: viewModel.recommendations)
    }
}
