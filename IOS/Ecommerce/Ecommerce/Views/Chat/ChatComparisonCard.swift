import SwiftUI

struct ChatComparisonCard: View {
    let productA: Product
    let productB: Product
    
    var body: some View {
        HStack(spacing: 0) {
            comparisonHalf(product: productA, isWinner: productA.price <= productB.price)
            Divider()
            comparisonHalf(product: productB, isWinner: productB.price < productA.price)
        }
        .frame(maxWidth: 300)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }

    @ViewBuilder
    private func comparisonHalf(product: Product, isWinner: Bool) -> some View {
        VStack(alignment: .center, spacing: 6) {
            Text(product.name)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Text(String(format: "$%.2f", product.price))
                .font(.caption)
                .fontWeight(.semibold)
            
            if isWinner {
                Text("Best value")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
    }
}
