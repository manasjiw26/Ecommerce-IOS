import SwiftUI

/// Stand-alone sign-up screen (used when navigated to directly, e.g. from ProfileView).
/// The embedded version used inside `AuthPromptSheet` lives in `AuthPromptSheet.swift`.
struct SignUpView: View {
    var onSignUpSuccess: () -> Void
    var onBack: () -> Void

    @StateObject private var viewModel = AuthViewModel()
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
                        Text("ShopEase")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 32)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Create account")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        Text("Join ShopEase — it's free")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .padding(.bottom, 32)

                    VStack(spacing: 14) {
                        DarkAuthField(placeholder: "Full Name", text: $viewModel.name, icon: "person", isSecure: false)
                            .focused($focusedField, equals: .name).submitLabel(.next).onSubmit { focusedField = .email }
                        DarkAuthField(placeholder: "Email", text: $viewModel.email, icon: "envelope", isSecure: false)
                            .focused($focusedField, equals: .email).submitLabel(.next).onSubmit { focusedField = .password }
                        DarkAuthField(placeholder: "Password", text: $viewModel.password, icon: "lock", isSecure: true)
                            .focused($focusedField, equals: .password).submitLabel(.next).onSubmit { focusedField = .confirm }
                        DarkAuthField(placeholder: "Confirm Password", text: $viewModel.confirmPassword, icon: "lock.shield", isSecure: true)
                            .focused($focusedField, equals: .confirm).submitLabel(.done).onSubmit { attemptSignUp() }

                        if let error = viewModel.errorMessage {
                            Text(error).font(.caption).foregroundColor(.red.opacity(0.9)).padding(.horizontal, 4)
                        }
                    }
                    .padding(.bottom, 40)

                    Button(action: attemptSignUp) {
                        ZStack {
                            if viewModel.isLoading { ProgressView().tint(.black) }
                            else { Text("Create Account").font(.headline).foregroundColor(.black) }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(14)
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 28)
            }
        }
    }

    private func attemptSignUp() {
        focusedField = nil
        viewModel.attemptSignUp(onSuccess: onSignUpSuccess)
    }
}
