import SwiftUI

struct ChatProductCarousel: View {
    let products: [Product]
    let viewModel: ChatViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(products) { product in
                    ChatProductCard(product: product, viewModel: viewModel)
                }
            }
            // 16 for ChatView padding + 36 for avatar indent
            .padding(.leading, 16 + 36)
            .padding(.trailing, 16)
            .padding(.vertical, 4)
        }
        // Negate the 16pt horizontal padding from ChatView so the scrollview hits the screen edges
        .padding(.horizontal, -16)
    }
}
