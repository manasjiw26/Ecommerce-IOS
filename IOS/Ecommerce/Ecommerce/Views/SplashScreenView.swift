import SwiftUI

/// Full-screen animated splash shown for ~1.8 s on cold launch.
/// Transitions automatically to the main app once the timer fires.
struct SplashScreenView: View {

    @State private var logoScale: CGFloat  = 0.7
    @State private var logoOpacity: Double = 0.0
    @State private var taglineOpacity: Double = 0.0
    @State private var ringScale: CGFloat  = 0.6
    @State private var ringOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Rich dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.10),
                    Color(red: 0.10, green: 0.08, blue: 0.18),
                    Color(red: 0.04, green: 0.04, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle background rings
            Circle()
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                .frame(width: 340, height: 340)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                .frame(width: 220, height: 220)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            VStack(spacing: 28) {
                // Logo mark
                ZStack {
                    // Glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.18), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 110, height: 110)

                    // Icon background
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.14), Color.white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )

                    // Shopping bag icon
                    Image(systemName: "bag.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                // Brand name
                VStack(spacing: 6) {
                    Text("ShopEase")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1)

                    Text("Premium shopping, effortlessly.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .opacity(taglineOpacity)
                }
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
        }
        .onAppear {
            // Staggered entrance
            withAnimation(.spring(response: 0.7, dampingFraction: 0.68).delay(0.1)) {
                logoScale   = 1.0
                logoOpacity = 1.0
                ringScale   = 1.0
                ringOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.55)) {
                taglineOpacity = 1.0
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
