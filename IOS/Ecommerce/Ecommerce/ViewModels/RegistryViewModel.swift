import Foundation
import Combine

@MainActor
class RegistryViewModel: ObservableObject {
    @Published var currentRegistry: Registry?
    @Published var registryItems: [RegistryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchUserRegistry() async {
        guard let user = AuthSession.shared.currentUser else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let registries = try await RegistryService.shared.fetchUserRegistries(userId: user.id)
            self.currentRegistry = registries.first
            
            if let registry = self.currentRegistry {
                self.registryItems = try await RegistryService.shared.fetchRegistryItems(registryId: registry.id)
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func createRegistry(eventType: String, eventDate: Date, isPublic: Bool) async {
        guard let user = AuthSession.shared.currentUser else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: eventDate)
        
        let dto = RegistryCreationDTO(
            userId: user.id,
            eventType: eventType,
            eventDate: dateString,
            eventLocation: nil,
            isPublic: isPublic
        )
        
        do {
            let newRegistry = try await RegistryService.shared.createRegistry(dto: dto)
            self.currentRegistry = newRegistry
            self.registryItems = []
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func addItemToRegistry(productId: Int) async {
        guard let registry = currentRegistry else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let newItem = try await RegistryService.shared.addItemToRegistry(registryId: registry.id, productId: productId)
            // Re-fetch items to get the full product join
            self.registryItems = try await RegistryService.shared.fetchRegistryItems(registryId: registry.id)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
