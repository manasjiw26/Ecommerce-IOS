import SwiftUI

struct SearchEmptyStateView: View {
    let query: String
    var trending: [String] = []
    var onTrendingTap: ((String) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            // Icon
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGray6))
                    .frame(width: 72, height: 72)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)

            // Heading
            Text("No results for \"\(query)\"")
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            // Body
            Text("Try a different spelling, or browse\nby category below.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 40)

            // Trending fallback chips
            if !trending.isEmpty {
                Text("TRENDING")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .kerning(0.6)
                    .padding(.top, 36)
                    .padding(.bottom, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(trending, id: \.self) { term in
                            Button { onTrendingTap?(term) } label: {
                                Text(term.capitalized)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(UIColor.systemBackground))
                                    .foregroundColor(.primary)
                                    .clipShape(Capsule())
                                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            Spacer(minLength: 40)
        }
    }
}
