import SwiftUI

struct TrendingSearchesView: View {
    let trending: [String]
    let onSelect: (String) -> Void

    var body: some View {
        if !trending.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("TRENDING")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .kerning(0.6)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(trending, id: \.self) { term in
                            Button { onSelect(term) } label: {
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
                }
            }
        }
    }
}
