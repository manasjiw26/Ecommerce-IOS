import Foundation

struct Address: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var label: String // e.g. Home, Work
    var fullName: String
    var phone: String
    var line1: String
    var line2: String
    var city: String
    var state: String
    var zip: String

    var oneLine: String {
        let parts = [line1, line2, city, state, zip].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }
}

