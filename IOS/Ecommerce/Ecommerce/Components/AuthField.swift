import SwiftUI

/// Light-mode styled auth input field (used by LoginView and SignUpView)
struct LightAuthField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    let isSecure: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            if isSecure {
                SecureField("", text: $text,
                            prompt: Text(placeholder).foregroundColor(.secondary.opacity(0.7)))
                    .foregroundColor(.primary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } else {
                TextField("", text: $text,
                          prompt: Text(placeholder).foregroundColor(.secondary.opacity(0.7)))
                    .foregroundColor(.primary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(placeholder.lowercased().contains("email") ? .emailAddress : .default)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}
