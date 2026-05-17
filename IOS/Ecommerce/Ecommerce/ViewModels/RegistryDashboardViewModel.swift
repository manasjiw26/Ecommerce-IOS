import Foundation
import Combine
import SwiftUI

@MainActor
class RegistryDashboardViewModel: ObservableObject {
    @Published var registry: MockRegistryExtended
    @Published var items: [RegistryItem] = []
    
    // UI Navigation & Sheet States
    @Published var showingEditSheet = false
    @Published var showingAddProductsSheet = false
    @Published var selectedItemForTagging: RegistryItem? = nil
    @Published var showShareSheet = false
    @Published var selectedProductForDetail: Product? = nil
    @Published var selectedItemForContributors: RegistryItem? = nil
    
    // Loading States
    @Published var isLoadingDashboard = false
    @Published var dashboardLoadingMessage = "Loading registry..."
    @Published var addingBundleTypes: Set<String> = []
    
    // Toast States
    @Published var showingToast = false
    @Published var toastMessage = ""
    
    // Delete Confirmation
    @Published var itemToDelete: RegistryItem? = nil
    @Published var showingItemDeleteConfirmation = false
    
    init(registry: MockRegistryExtended) {
        self.registry = registry
        // Attempt to load from cache immediately to prevent flash of empty content
        if let cachedItems = MockRegistryService.shared.registryItems[registry.id] {
            self.items = cachedItems
        }
    }
    
    func refreshDashboard(message: String? = nil) async {
        if let msg = message {
            dashboardLoadingMessage = msg
            isLoadingDashboard = true
        }
        
        do {
            try await MockRegistryService.shared.fetchRegistryDashboard(registryId: registry.id)
            if let updatedRegistry = MockRegistryService.shared.registries.first(where: { $0.id == registry.id }) {
                self.registry = updatedRegistry
            }
            self.items = MockRegistryService.shared.registryItems[registry.id] ?? []
        } catch {
            print("❌ Failed to fetch dashboard: \(error.localizedDescription)")
            showToast("Failed to load registry: \(error.localizedDescription)")
        }
        
        if message != nil {
            isLoadingDashboard = false
        }
    }
    
    func applySmartBundle(_ bundle: SmartBundleOption) {
        addingBundleTypes.insert(bundle.bundleType)
        Task {
            do {
                try await MockRegistryService.shared.applySmartBundle(registryId: registry.id, bundleType: bundle.bundleType)
                await refreshDashboard(message: nil)
                showToast("Added \(bundle.title) to registry!")
            } catch {
                print("❌ Failed to apply bundle: \(error.localizedDescription)")
                showToast("Failed to add bundle: \(error.localizedDescription)")
            }
            addingBundleTypes.remove(bundle.bundleType)
        }
    }
    
    func deleteItem(_ item: RegistryItem) {
        itemToDelete = item
        showingItemDeleteConfirmation = true
    }
    
    func confirmDelete() {
        guard let item = itemToDelete else { return }
        Task {
            do {
                try await RegistryService.shared.deleteRegistryItem(registryId: registry.id, itemId: item.id)
                await refreshDashboard(message: nil)
                showToast("Item removed from registry")
            } catch {
                print("❌ Failed to delete item: \(error.localizedDescription)")
                showToast("Failed to delete item")
            }
        }
    }
    
    func toggleMostWanted(for item: RegistryItem) {
        Task {
            do {
                MockRegistryService.shared.toggleMostWanted(registryId: registry.id, itemId: item.id)
                // Let the service update the backend, we refresh locally
                await refreshDashboard(message: nil)
            }
        }
    }
    
    func toggleGroupGift(for item: RegistryItem) {
        Task {
            do {
                MockRegistryService.shared.toggleGroupGift(registryId: registry.id, itemId: item.id)
                await refreshDashboard(message: nil)
            }
        }
    }
    
    func showToast(_ message: String) {
        self.toastMessage = message
        withAnimation { self.showingToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { self.showingToast = false }
        }
    }
}
