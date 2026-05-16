import Foundation

struct PairItWithProduct: Identifiable, Equatable {
    let id = UUID()
    let product: Product
    /// AI-generated one-sentence reasoning returned by the backend.
    /// Nil when no reasoning is available (e.g. fallback popular items).
    let aiReasoning: String?

    static func == (lhs: PairItWithProduct, rhs: PairItWithProduct) -> Bool {
        lhs.product.id == rhs.product.id
    }
}
