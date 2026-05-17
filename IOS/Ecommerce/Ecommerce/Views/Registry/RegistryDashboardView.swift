import SwiftUI

struct RegistryDashboardView: View {
    @ObservedObject var viewModel: RegistryViewModel
    
    var body: some View {
        List {
            Section {
                AIStatusBar(messages: [
                    "✦ Building your perfect registry",
                    "✦ I can find gifts in any budget",
                    "✦ Analyzing wish patterns",
                    "✦ Smart bundles available for your list"
                ])
            }
            .listRowBackground(Color.clear)
            
            if let registry = viewModel.currentRegistry {
                Section(header: Text("Registry Details")) {
                    Text("Event: \(registry.eventType)")
                    Text("Date: \(registry.eventDate)")
                    Text("Status: \(registry.isPublic ? "Public" : "Private")")
                }
            }
            
            Section(header: Text("Your Items")) {
                if viewModel.registryItems.isEmpty {
                    Text("You haven't added any items yet.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(viewModel.registryItems) { item in
                        HStack {
                            if let product = item.products {
                                CachedImageView(urlString: product.imageUrl ?? "") { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color.gray
                                }
                                .frame(width: 50, height: 50)
                                .cornerRadius(8)
                                
                                VStack(alignment: .leading) {
                                    Text(product.name)
                                        .font(.headline)
                                    Text("Requested: \(item.quantityRequested) | Received: \(item.quantityReceived)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("Unknown Product")
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.fetchUserRegistry()
        }
    }
}
