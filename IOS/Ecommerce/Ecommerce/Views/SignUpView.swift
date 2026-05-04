import SwiftUI

struct SignUpView: View {
    var onSignUpSuccess: () -> Void
    var onBack: () -> Void

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @FocusState private var focusedField: Field?

    enum Field { case name, email, password, confirm }

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
                    Text("Create account")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Join ShopEase today")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)

                VStack(spacing: 14) {
                    LightAuthField(placeholder: "Full Name", text: $name, icon: "person", isSecure: false)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }

                    LightAuthField(placeholder: "Email", text: $email, icon: "envelope", isSecure: false)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }

                    LightAuthField(placeholder: "Password", text: $password, icon: "lock", isSecure: true)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirm }

                    LightAuthField(placeholder: "Confirm Password", text: $confirmPassword, icon: "lock.shield", isSecure: true)
                        .focused($focusedField, equals: .confirm)
                        .submitLabel(.done)
                        .onSubmit { attemptSignUp() }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 28)

                Spacer()

                Button(action: attemptSignUp) {
                    ZStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Create Account")
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

    private func attemptSignUp() {
        focusedField = nil
        errorMessage = nil
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        guard email.contains("@") else { errorMessage = "Please enter a valid email."; return }
        guard password.count >= 6 else { errorMessage = "Password must be at least 6 characters."; return }
        guard password == confirmPassword else { errorMessage = "Passwords do not match."; return }

        isLoading = true
        Task {
            do {
                _ = try await AuthService.shared.signUp(name: name, email: email, password: password)
                await MainActor.run { isLoading = false; onSignUpSuccess() }
            } catch {
                await MainActor.run { isLoading = false; errorMessage = error.localizedDescription }
            }
        }
    }
}
