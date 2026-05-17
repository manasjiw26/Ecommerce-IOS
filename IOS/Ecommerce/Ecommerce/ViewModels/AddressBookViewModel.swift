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
        if addresses.isEmpty || addresses.contains(where: { $0.line1.isEmpty }) {
            // Seed a complete beautiful default address so checkout and cart display immediately.
            let seeded = Address(
                label: "Home",
                fullName: AuthSession.shared.currentUser?.name ?? "Customer",
                phone: "+1 (555) 019-2834",
                line1: "1600 Amphitheatre Parkway",
                line2: "",
                city: "Mountain View",
                state: "CA",
                zip: "94043"
            )
            addresses = [seeded]
            selectedAddressId = seeded.id
            persist()
            syncSelectedAddressToBackend()
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
        syncSelectedAddressToBackend()
    }

    func delete(_ id: String) {
        addresses.removeAll { $0.id == id }
        if selectedAddressId == id { selectedAddressId = addresses.first?.id }
        persist()
        syncSelectedAddressToBackend()
    }

    func select(_ id: String?) {
        selectedAddressId = id
        persist()
        syncSelectedAddressToBackend()
    }

    func syncSelectedAddressToBackend() {
        guard let address = selectedAddress else { return }
        let deviceId = RecommendationEngine.shared.deviceId
        
        guard let url = URL(string: "\(Config.apiBaseURL)/users/address") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "device_id": deviceId,
            "address": [
                "id": address.id,
                "label": address.label,
                "fullName": address.fullName,
                "phone": address.phone,
                "line1": address.line1,
                "line2": address.line2,
                "city": address.city,
                "state": address.state,
                "zip": address.zip
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }

    func fetchAddressFromBackend() async {
        let deviceId = RecommendationEngine.shared.deviceId
        guard let url = URL(string: "\(Config.apiBaseURL)/users/address?device_id=\(deviceId)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct BackendResponse: Codable {
                let address: Address?
            }
            let response = try JSONDecoder().decode(BackendResponse.self, from: data)
            if let address = response.address {
                if let idx = addresses.firstIndex(where: { $0.id == address.id }) {
                    addresses[idx] = address
                } else {
                    addresses.append(address)
                }
                selectedAddressId = address.id
                persist()
            }
        } catch {
            print("Failed to fetch address from backend: \(error.localizedDescription)")
        }
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

