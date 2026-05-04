import SwiftUI

struct OnboardingView: View {
    var onLogin: () -> Void
    var onSignUp: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo / Brand
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.black)
                            .frame(width: 90, height: 90)
                        Text("S")
                            .font(.system(size: 40, weight: .black))
                            .foregroundColor(.white)
                    }

                    Text("ShopEase")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Premium kitchenware, delivered\nto your door.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // Feature pills
                HStack(spacing: 10) {
                    FeaturePill(icon: "cart.fill", text: "Easy Shopping", color: .blue)
                    FeaturePill(icon: "bolt.fill", text: "Fast Checkout", color: .orange)
                    FeaturePill(icon: "star.fill", text: "Top Brands", color: .yellow)
                }
                .padding(.bottom, 48)

                // Buttons
                VStack(spacing: 14) {
                    Button(action: onSignUp) {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(14)
                    }

                    Button(action: onLogin) {
                        Text("Log In")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
        .preferredColorScheme(.light)
    }
}

struct FeaturePill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.separator), lineWidth: 0.5))
    }
}
