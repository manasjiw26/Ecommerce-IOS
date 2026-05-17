import SwiftUI

// MARK: - AuthPromptSheet
/// Beautiful bottom sheet shown when a guest tries to access a protected action
/// (checkout, orders tab, registry tab).
/// On successful auth it fires `onAuthenticated()` so the caller can resume
/// the interrupted action automatically.
struct AuthPromptSheet: View {

    let context: AuthPromptContext
    let onAuthenticated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var route: AuthRoute = .choice

    enum AuthRoute { case choice, login, signUp }

    var body: some View {
        Group {
            switch route {
            case .choice:
                choiceView
            case .login:
                EmbeddedLoginView(
                    onSuccess: { dismiss(); onAuthenticated() },
                    onBack:    { withAnimation { route = .choice } }
                )
            case .signUp:
                EmbeddedSignUpView(
                    onSuccess: { dismiss(); onAuthenticated() },
                    onBack:    { withAnimation { route = .choice } }
                )
            }
        }
        .animation(.easeInOut(duration: 0.22), value: route)
    }

    // MARK: - Choice screen

    private var choiceView: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black, Color(white: 0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: context.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 18)

            // Title / subtitle
            Text(context.title)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)

            Text(context.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)
                .padding(.bottom, 32)

            // Benefit pills
            HStack(spacing: 10) {
                BenefitPill(icon: "lock.shield.fill",  text: "Secure",   color: .green)
                BenefitPill(icon: "arrow.triangle.2.circlepath", text: "Sync cart", color: .blue)
                BenefitPill(icon: "star.fill", text: "Rewards", color: .orange)
            }
            .padding(.bottom, 32)

            // CTAs
            VStack(spacing: 12) {
                Button(action: { withAnimation { route = .signUp } }) {
                    Text("Create Free Account")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.black, Color(white: 0.18)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                }

                Button(action: { withAnimation { route = .login } }) {
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
            .padding(.horizontal, 24)

            // Continue as guest (only for soft-auth contexts)
            if context.allowGuestContinue {
                Button(action: { dismiss() }) {
                    Text("Continue browsing as Guest")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 14)
                .padding(.bottom, 8)
            }

            Spacer().frame(height: 24)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Context descriptor

struct AuthPromptContext {
    let title: String
    let subtitle: String
    let icon: String
    var allowGuestContinue: Bool = true

    static let checkout = AuthPromptContext(
        title:    "Sign in to Checkout",
        subtitle: "Your cart items are saved — create an account to place your order and track it.",
        icon:     "bag.fill",
        allowGuestContinue: false
    )

    static let orders = AuthPromptContext(
        title:    "Track Your Orders",
        subtitle: "Sign in to see your order history, returns, and live shipping updates.",
        icon:     "shippingbox.fill"
    )

    static let registry = AuthPromptContext(
        title:    "Create a Registry",
        subtitle: "Sign in to build, manage, and share your gift registry with friends and family.",
        icon:     "gift.fill"
    )
}

// MARK: - Benefit pill

private struct BenefitPill: View {
    let icon: String; let text: String; let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.separator), lineWidth: 0.5))
    }
}

// MARK: - Embedded Login (inside the sheet)

private struct EmbeddedLoginView: View {
    let onSuccess: () -> Void
    let onBack:    () -> Void

    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focused: LoginField?

    enum LoginField { case email, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Back
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 28)

                // ShopEase brand mark
                ShopEaseAuthHeader(headline: "Welcome back", subhead: "Sign in to continue")
                    .padding(.bottom, 28)

                // Fields
                VStack(spacing: 14) {
                    ShopEaseInputField(placeholder: "Email", text: $viewModel.email, icon: "envelope", isSecure: false)
                        .focused($focused, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focused = .password }

                    ShopEaseInputField(placeholder: "Password", text: $viewModel.password, icon: "lock", isSecure: true)
                        .focused($focused, equals: .password)
                        .submitLabel(.done)
                        .onSubmit { attempt() }

                    if let err = viewModel.errorMessage {
                        Text(err).font(.caption).foregroundColor(.red).padding(.horizontal, 4)
                    }
                }

                Spacer().frame(height: 32)

                // CTA
                Button(action: attempt) {
                    ZStack {
                        if viewModel.isLoading { ProgressView().tint(.white) }
                        else { Text("Log In").font(.headline).foregroundColor(.white) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .cornerRadius(14)
                }
                .disabled(viewModel.isLoading)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
    }

    private func attempt() {
        focused = nil
        viewModel.attemptLogin(onSuccess: onSuccess)
    }
}

// MARK: - Embedded Sign Up (inside the sheet)

private struct EmbeddedSignUpView: View {
    let onSuccess: () -> Void
    let onBack:    () -> Void

    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focused: SignUpField?

    enum SignUpField { case name, email, password, confirm }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 28)

                ShopEaseAuthHeader(headline: "Create account", subhead: "Join ShopEase — it's free")
                    .padding(.bottom, 28)

                VStack(spacing: 14) {
                    ShopEaseInputField(placeholder: "Full Name", text: $viewModel.name, icon: "person", isSecure: false)
                        .focused($focused, equals: .name).submitLabel(.next).onSubmit { focused = .email }
                    ShopEaseInputField(placeholder: "Email", text: $viewModel.email, icon: "envelope", isSecure: false)
                        .focused($focused, equals: .email).submitLabel(.next).onSubmit { focused = .password }
                    ShopEaseInputField(placeholder: "Password", text: $viewModel.password, icon: "lock", isSecure: true)
                        .focused($focused, equals: .password).submitLabel(.next).onSubmit { focused = .confirm }
                    ShopEaseInputField(placeholder: "Confirm Password", text: $viewModel.confirmPassword, icon: "lock.shield", isSecure: true)
                        .focused($focused, equals: .confirm).submitLabel(.done).onSubmit { attempt() }

                    if let err = viewModel.errorMessage {
                        Text(err).font(.caption).foregroundColor(.red).padding(.horizontal, 4)
                    }
                }

                Spacer().frame(height: 32)

                Button(action: attempt) {
                    ZStack {
                        if viewModel.isLoading { ProgressView().tint(.white) }
                        else { Text("Create Account").font(.headline).foregroundColor(.white) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .cornerRadius(14)
                }
                .disabled(viewModel.isLoading)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
    }

    private func attempt() {
        focused = nil
        viewModel.attemptSignUp(onSuccess: onSuccess)
    }
}

// MARK: - Shared UI components

/// Compact ShopEase header used inside the auth sheet.
struct ShopEaseAuthHeader: View {
    let headline: String
    let subhead:  String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                Text("ShopEase")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 12)

            Text(headline)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            Text(subhead)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

/// Styled input field used across auth screens.
struct ShopEaseInputField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    let isSecure: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isFocused ? .primary : .secondary)
                .frame(width: 22)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .focused($isFocused)
                    .font(.body)
            } else {
                TextField(placeholder, text: $text)
                    .focused($isFocused)
                    .font(.body)
                    .autocapitalization(.none)
                    .keyboardType(placeholder.lowercased().contains("email") ? .emailAddress : .default)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? Color.primary.opacity(0.6) : Color(.separator), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
