import Foundation

struct AutocompleteProduct: Codable, Identifiable {
    let id: Int
    let name: String
    let category: String?
}

struct AutocompleteResponse: Codable {
    let recent: [String]
    let trending: [String]
    let categories: [String]
    let products: [AutocompleteProduct]
    
    // Helper to check if everything is empty
    var isEmpty: Bool {
        return recent.isEmpty && trending.isEmpty && categories.isEmpty && products.isEmpty
    }
}
