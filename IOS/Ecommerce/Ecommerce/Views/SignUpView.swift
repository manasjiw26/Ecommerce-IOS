import SwiftUI

/// Stand-alone sign-up screen (used when navigated to directly, e.g. from ProfileView).
/// The embedded version used inside `AuthPromptSheet` lives in `AuthPromptSheet.swift`.
struct SignUpView: View {
    var onSignUpSuccess: () -> Void
    var onBack: () -> Void

    @State private var name            = ""
    @State private var email           = ""
    @State private var password        = ""
    @State private var confirmPassword = ""
    @State private var isLoading       = false
    @State private var errorMessage: String? = nil
    @FocusState private var focusedField: Field?

    enum Field { case name, email, password, confirm }

    var body: some View {
        ZStack {
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
                    // Back
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

                    // Brand
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

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Create account")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        Text("Join Shop Ease — it's free")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .padding(.bottom, 32)

                    VStack(spacing: 14) {
                        DarkAuthField(placeholder: "Full Name", text: $name, icon: "person", isSecure: false)
                            .focused($focusedField, equals: .name).submitLabel(.next).onSubmit { focusedField = .email }
                        DarkAuthField(placeholder: "Email", text: $email, icon: "envelope", isSecure: false)
                            .focused($focusedField, equals: .email).submitLabel(.next).onSubmit { focusedField = .password }
                        DarkAuthField(placeholder: "Password", text: $password, icon: "lock", isSecure: true)
                            .focused($focusedField, equals: .password).submitLabel(.next).onSubmit { focusedField = .confirm }
                        DarkAuthField(placeholder: "Confirm Password", text: $confirmPassword, icon: "lock.shield", isSecure: true)
                            .focused($focusedField, equals: .confirm).submitLabel(.done).onSubmit { attemptSignUp() }

                        if let error = errorMessage {
                            Text(error).font(.caption).foregroundColor(.red.opacity(0.9)).padding(.horizontal, 4)
                        }
                    }
                    .padding(.bottom, 40)

                    Button(action: attemptSignUp) {
                        ZStack {
                            if isLoading { ProgressView().tint(.black) }
                            else { Text("Create Account").font(.headline).foregroundColor(.black) }
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

    private func attemptSignUp() {
        focusedField = nil; errorMessage = nil
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields."; return
        }
        guard email.contains("@") else { errorMessage = "Enter a valid email."; return }
        guard password.count >= 6 else { errorMessage = "Password must be ≥ 6 characters."; return }
        guard password == confirmPassword else { errorMessage = "Passwords do not match."; return }

        isLoading = true
        Task {
            do {
                _ = try await AuthService.shared.signUp(name: name, email: email, password: password)
                await GuestDataMigrator.migrate()
                await MainActor.run { isLoading = false; onSignUpSuccess() }
            } catch {
                await MainActor.run { isLoading = false; errorMessage = error.localizedDescription }
            }
        }
    }
}
