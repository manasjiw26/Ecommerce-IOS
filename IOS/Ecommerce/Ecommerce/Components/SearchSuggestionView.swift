import SwiftUI

struct SearchSuggestionView: View {
    let response: AutocompleteResponse
    let onSelect: (String) -> Void
    
    var body: some View {
        Group {
            if !response.recent.isEmpty {
                Section(header: Text("Recent Searches").font(.caption).foregroundColor(.secondary)) {
                    ForEach(response.recent, id: \.self) { recent in
                        Button(action: { onSelect(recent) }) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                Text(recent)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            
            if !response.categories.isEmpty {
                Section(header: Text("Categories").font(.caption).foregroundColor(.secondary)) {
                    ForEach(response.categories, id: \.self) { category in
                        Button(action: { onSelect(category) }) {
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundColor(.blue)
                                Text("Search in \(Text(category).fontWeight(.medium).foregroundColor(.primary))")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            
            if !response.products.isEmpty {
                Section(header: Text("Products").font(.caption).foregroundColor(.secondary)) {
                    ForEach(response.products) { product in
                        Button(action: { onSelect(product.name) }) {
                            HStack {
                                Image(systemName: "tag")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text(product.name)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    if let category = product.category {
                                        Text(category)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }
}
