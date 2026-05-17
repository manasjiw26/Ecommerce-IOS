import SwiftUI
import Combine

// MARK: - AI Spark Badge
// Reusable animated ✦ badge used to mark AI-generated content.
// Two sizes: .small (for product cards) and .tiny (for inline labels).
struct AISparkBadge: View {
    var label: String = "AI Pick"
    var size: BadgeSize = .small
    @State private var appeared = false

    enum BadgeSize { case small, tiny }

    var fontSize: CGFloat { size == .small ? 10 : 9 }
    var hPad: CGFloat { size == .small ? 8 : 6 }
    var vPad: CGFloat { size == .small ? 4 : 3 }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: fontSize - 1, weight: .bold))
            Text(label)
                .font(.system(size: fontSize, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .background(
            Capsule().fill(Color.black.opacity(0.80))
        )
        .scaleEffect(appeared ? 1.0 : 0.4)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.62).delay(0.15)) {
                appeared = true
            }
        }
        .onDisappear {
            appeared = false
        }
    }
}
