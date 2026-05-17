import SwiftUI
import Combine

// MARK: - AI Aura Background
// A subtle, rotating angular gradient that gives AI-related elements
// an ambient "living" glow. Used as a background on reasoning cards,
// recommendation cards, and occasion cards.
struct AIAura: View {
    var intensity: Double = 0.06
    var animated: Bool = true
    @State private var rotation: Double = 0

    var body: some View {
        AngularGradient(
            gradient: Gradient(colors: [
                Color(hex: "#0a0a0a"),
                Color(hex: "#1a1040").opacity(intensity * 3),
                Color(hex: "#0d0d1a").opacity(intensity * 2),
                Color(hex: "#0a0a0a"),
                Color(hex: "#1a0a2a").opacity(intensity * 2),
                Color(hex: "#0a0a0a")
            ]),
            center: .center
        )
        .rotationEffect(.degrees(rotation))
        .blur(radius: 50)
        .onAppear {
            guard animated else { return }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - View Extension
extension View {
    func aiAura(intensity: Double = 0.06) -> some View {
        self.background(AIAura(intensity: intensity))
    }
}

// MARK: - Color Hex Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int & 0xFF0000) >> 16) / 255
        let g = Double((int & 0x00FF00) >> 8) / 255
        let b = Double(int & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
