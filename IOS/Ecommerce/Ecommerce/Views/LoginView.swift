import SwiftUI

/// Stand-alone login screen (used when navigated to directly, e.g. from ProfileView).
/// The embedded version used inside `AuthPromptSheet` lives in `AuthPromptSheet.swift`.
struct LoginView: View {
    var onLoginSuccess: () -> Void
    var onBack: () -> Void

    @State private var email    = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ZStack {
            // Rich dark background matching the splash
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.10),
                    Color(red: 0.10, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Back button
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 40)

                    // Shop Ease logo
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: "bag.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text("Shop Ease")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 32)

                    // Headline
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Welcome back")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        Text("Sign in to your account")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .padding(.bottom, 36)

                    // Fields
                    VStack(spacing: 16) {
                        DarkAuthField(placeholder: "Email", text: $email, icon: "envelope", isSecure: false)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }

                        DarkAuthField(placeholder: "Password", text: $password, icon: "lock", isSecure: true)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.done)
                            .onSubmit { attemptLogin() }

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.9))
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.bottom, 40)

                    // CTA
                    Button(action: attemptLogin) {
                        ZStack {
                            if isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text("Log In")
                                    .font(.headline)
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(14)
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 28)
            }
        }
    }

    private func attemptLogin() {
        focusedField = nil; errorMessage = nil
        guard !email.isEmpty, !password.isEmpty else { errorMessage = "Please fill in all fields."; return }
        isLoading = true
        Task {
            do {
                _ = try await AuthService.shared.login(email: email, password: password)
                await GuestDataMigrator.migrate()
                await MainActor.run { isLoading = false; onLoginSuccess() }
            } catch {
                await MainActor.run { isLoading = false; errorMessage = error.localizedDescription }
            }
        }
    }
}

// MARK: - Dark-themed input field (used in standalone auth screens)

struct DarkAuthField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    let isSecure: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isFocused ? .white : .white.opacity(0.5))
                .frame(width: 22)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .focused($isFocused)
                    .font(.body)
                    .foregroundColor(.white)
                    .tint(.white)
            } else {
                TextField(placeholder, text: $text)
                    .focused($isFocused)
                    .font(.body)
                    .foregroundColor(.white)
                    .tint(.white)
                    .autocapitalization(.none)
                    .keyboardType(placeholder.lowercased().contains("email") ? .emailAddress : .default)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? Color.white.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
