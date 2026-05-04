import SwiftUI

struct LoginView: View {
    var onLoginSuccess: () -> Void
    var onBack: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                }
                .padding(.top, 60)
                .padding(.horizontal, 28)

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Sign in to your account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 36)

                VStack(spacing: 16) {
                    LightAuthField(placeholder: "Email", text: $email, icon: "envelope", isSecure: false)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }

                    LightAuthField(placeholder: "Password", text: $password, icon: "lock", isSecure: true)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.done)
                        .onSubmit { attemptLogin() }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 28)

                Spacer()

                Button(action: attemptLogin) {
                    ZStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Log In")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .cornerRadius(14)
                }
                .disabled(isLoading)
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
        .preferredColorScheme(.light)
    }

    private func attemptLogin() {
        focusedField = nil
        errorMessage = nil
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        isLoading = true
        Task {
            do {
                _ = try await AuthService.shared.login(email: email, password: password)
                await MainActor.run { isLoading = false; onLoginSuccess() }
            } catch {
                await MainActor.run { isLoading = false; errorMessage = error.localizedDescription }
            }
        }
    }
}
