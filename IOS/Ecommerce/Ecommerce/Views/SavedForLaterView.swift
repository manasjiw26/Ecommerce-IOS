import SwiftUI

struct SavedForLaterView: View {
    @EnvironmentObject var cartManager: CartManager
    @StateObject var vm: SavedForLaterViewModel

    @State private var showOOSAlert = false
    @State private var selectedOOSProduct: Product? = nil

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
                                            .fontWeight(.medium)
                                            .lineLimit(2)
                                        
                                        HStack(spacing: 8) {
                                            Text("$\(String(format: "%.2f", product.price))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            if (product.stock ?? 999) == 0 {
                                                Text("Out of Stock")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.red)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.red.opacity(0.1))
                                                    .cornerRadius(4)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Button(action: {
                                        if (product.stock ?? 999) == 0 {
                                            selectedOOSProduct = product
                                            showOOSAlert = true
                                        } else {
                                            let impact = UIImpactFeedbackGenerator(style: .medium)
                                            impact.impactOccurred()
                                            
                                            cartManager.addToCart(product: product)
                                            
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                                Task {
                                                    await vm.remove(productId: product.id)
                                                }
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add to Cart")
                                        }
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background((product.stock ?? 999) == 0 ? Color.gray.opacity(0.6) : Color.black)
                                        .cornerRadius(30)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .listRowSeparator(.hidden)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        Task { await vm.remove(productId: product.id) }
                                    } label: { Label("Remove", systemImage: "trash") }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(UIColor.systemBackground))
                }
            }
            .navigationTitle("Saved For Later")
            .task { await vm.refresh() }
            .alert("Item Out of Stock", isPresented: $showOOSAlert) {
                Button("Remove", role: .destructive) {
                    if let product = selectedOOSProduct {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            Task {
                                await vm.remove(productId: product.id)
                            }
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let product = selectedOOSProduct {
                    Text("'\(product.name)' is currently out of stock. Would you like to remove it from Saved for Later?")
                }
            }
        }
    }
}
