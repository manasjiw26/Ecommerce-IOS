import SwiftUI

struct SearchSuggestionView: View {
    let response: AutocompleteResponse
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !response.recent.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RECENT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .kerning(0.6)

                    VStack(spacing: 0) {
                        ForEach(Array(response.recent.enumerated()), id: \.element) { idx, recent in
                            Button { onSelect(recent) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .frame(width: 20)
                                    Text(recent)
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(.tertiaryLabel))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            if idx < response.recent.count - 1 {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .background(Color(UIColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
            }

            if !response.categories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CATEGORIES")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .kerning(0.6)

                    VStack(spacing: 0) {
                        ForEach(Array(response.categories.enumerated()), id: \.element) { idx, category in
                            Button { onSelect(category) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .frame(width: 20)
                                    Text("Search in \(category)")
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(.tertiaryLabel))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            if idx < response.categories.count - 1 {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .background(Color(UIColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
            }

            if !response.products.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PRODUCTS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .kerning(0.6)

                    VStack(spacing: 0) {
                        ForEach(Array(response.products.enumerated()), id: \.element.id) { idx, product in
                            Button { onSelect(product.name) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(product.name)
                                            .font(.system(size: 15))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        if let category = product.category {
                                            Text(category)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            if idx < response.products.count - 1 {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .background(Color(UIColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
            }
        }
    }
}
