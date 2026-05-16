import Foundation

struct PairItWithProduct: Identifiable, Equatable {
    let id = UUID()
    let product: Product
    let recommendationLabel: String
    
    static func == (lhs: PairItWithProduct, rhs: PairItWithProduct) -> Bool {
        lhs.product.id == rhs.product.id && lhs.recommendationLabel == rhs.recommendationLabel
    }
}
