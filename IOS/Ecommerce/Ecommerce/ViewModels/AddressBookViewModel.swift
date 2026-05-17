import Foundation
import Combine

@MainActor
final class AddressBookViewModel: ObservableObject {
    @Published var addresses: [Address] = []
    @Published var selectedAddressId: String? = nil

    private let addressesKey = "address_book_v1"
    private let selectedKey = "address_book_selected_v1"

    init() {
        load()
        if addresses.isEmpty {
            // Seed one reasonable default so checkout isn't a blank wall for demos.
            let seeded = Address(
                label: "Home",
                fullName: AuthSession.shared.currentUser?.name ?? "Customer",
                phone: "",
                line1: "",
                line2: "",
                city: "",
                state: "",
                zip: ""
            )
            addresses = [seeded]
            selectedAddressId = seeded.id
            persist()
        }
        if selectedAddressId == nil { selectedAddressId = addresses.first?.id }
    }

    var selectedAddress: Address? {
        guard let id = selectedAddressId else { return nil }
        return addresses.first(where: { $0.id == id })
    }

    func upsert(_ addr: Address) {
        if let idx = addresses.firstIndex(where: { $0.id == addr.id }) {
            addresses[idx] = addr
        } else {
            addresses.insert(addr, at: 0)
        }
        if selectedAddressId == nil { selectedAddressId = addr.id }
        persist()
    }

    func delete(_ id: String) {
        addresses.removeAll { $0.id == id }
        if selectedAddressId == id { selectedAddressId = addresses.first?.id }
        persist()
    }

    func select(_ id: String) {
        selectedAddressId = id
        persist()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: addressesKey),
           let decoded = try? JSONDecoder().decode([Address].self, from: data) {
            addresses = decoded
        }
        selectedAddressId = UserDefaults.standard.string(forKey: selectedKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(addresses) {
            UserDefaults.standard.set(data, forKey: addressesKey)
        }
        UserDefaults.standard.set(selectedAddressId, forKey: selectedKey)
    }
}

