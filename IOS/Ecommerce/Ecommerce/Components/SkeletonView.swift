import SwiftUI

// MARK: - Shimmer Modifier
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear,                            location: 0),
                            .init(color: Color.white.opacity(0.45),         location: 0.4),
                            .init(color: Color.white.opacity(0.65),         location: 0.5),
                            .init(color: Color.white.opacity(0.45),         location: 0.6),
                            .init(color: .clear,                            location: 1),
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 3)
                    .offset(x: geo.size.width * phase)
                    .blendMode(.screen)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.3)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2.0
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Product Card
struct SkeletonProductCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Image placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(height: 160)
                .shimmer()

            // Name placeholder — two lines
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(height: 13)
                    .shimmer()

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 13)
                    .shimmer()
            }

            // Price + button row
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 16)
                    .shimmer()

                Spacer()

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 36)
                    .shimmer()
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Skeleton Grid (6 placeholder cards)
struct SkeletonProductGrid: View {
    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<6, id: \.self) { _ in
                SkeletonProductCard()
            }
        }
        .padding()
    }
}

// MARK: - Skeleton Category Chips
struct SkeletonCategoryRow: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray5))
                    .frame(width: CGFloat([60, 80, 70, 90, 65][i]), height: 34)
                    .shimmer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                SkeletonCategoryRow()
            }
            SkeletonProductGrid()
        }
    }
}

// MARK: - Scale Button Style (used by camera icon in search bar)
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
