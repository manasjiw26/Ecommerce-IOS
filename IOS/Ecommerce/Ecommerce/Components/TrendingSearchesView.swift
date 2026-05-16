import SwiftUI

struct TrendingSearchesView: View {
    let trending: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        if !trending.isEmpty {
            Section(header: Text("Trending Searches").font(.caption).foregroundColor(.secondary)) {
                ForEach(trending, id: \.self) { term in
                    Button(action: { onSelect(term) }) {
                        HStack {
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.accentColor)
                            Text(term)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
            }
        } else {
            // Optional: return an empty view or just fall through
            EmptyView()
        }
    }
}
