import Foundation

// MARK: - Role
enum ChatRole: String, Codable {
    case user, assistant, system
}

// MARK: - Attachment (not persisted — rebuilt from live API data)
enum ChatAttachment {
    case products([Product])
    case order(PlacedOrder)
    case quickReplies([String])
    case cartSummary
    case priceComparison(Product, Product)
}

// MARK: - Message
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: ChatRole
    let text: String
    var attachments: [ChatAttachment]
    let timestamp: Date
    var isLoading: Bool

    // Attachments are transient — excluded from persistence
    enum CodingKeys: String, CodingKey {
        case id, role, text, timestamp, isLoading
    }

    init(role: ChatRole, text: String, attachments: [ChatAttachment] = [], isLoading: Bool = false) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.attachments = attachments
        self.timestamp = Date()
        self.isLoading = isLoading
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,     forKey: .id)
        role      = try c.decode(ChatRole.self, forKey: .role)
        text      = try c.decode(String.self,   forKey: .text)
        timestamp = try c.decode(Date.self,     forKey: .timestamp)
        isLoading = (try? c.decode(Bool.self,   forKey: .isLoading)) ?? false
        attachments = []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,        forKey: .id)
        try c.encode(role,      forKey: .role)
        try c.encode(text,      forKey: .text)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(isLoading, forKey: .isLoading)
    }
}
