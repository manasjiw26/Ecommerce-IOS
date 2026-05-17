import SwiftUI

struct SavedForLaterView: View {
    @EnvironmentObject var cartManager: CartManager
    @StateObject var vm: SavedForLaterViewModel

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Loading…")
                } else if let err = vm.errorMessage {
                    VStack(spacing: 12) {
                        Text("Couldn't load saved items")
                            .font(.headline)
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") { Task { await vm.refresh() } }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if vm.items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Nothing saved yet")
                            .font(.headline)
                        Text("Save items for later from product pages or the cart.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(vm.items) { item in
                            if let product = item.product {
                                HStack(spacing: 12) {
                                    if let url = product.imageUrl {
                                        CachedImageView(urlString: url) { img in
                                            img.resizable().scaledToFill()
                                        } placeholder: {
                                            Color(.systemGray5)
                                        }
                                        .frame(width: 52, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(product.name)
                                            .font(.subheadline)
                                            .lineLimit(2)
                                        Text("$\(String(format: "%.2f", product.price))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button("Add") { cartManager.addToCart(product: product) }
                                        .buttonStyle(.bordered)
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        Task { await vm.remove(productId: product.id) }
                                    } label: { Label("Remove", systemImage: "trash") }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Saved For Later")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await vm.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await vm.refresh() }
        }
    }
}

