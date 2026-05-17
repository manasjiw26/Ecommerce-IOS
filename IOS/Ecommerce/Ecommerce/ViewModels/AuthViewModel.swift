import Foundation
import Combine
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var name = ""
    
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Attempt Login
    func attemptLogin(onSuccess: @escaping () -> Void) {
        errorMessage = nil
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        
        isLoading = true
        Task {
            do {
                _ = try await AuthService.shared.login(email: email, password: password)
                await GuestDataMigrator.migrate()
                isLoading = false
                onSuccess()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // Attempt Sign Up
    func attemptSignUp(onSuccess: @escaping () -> Void) {
        errorMessage = nil
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        guard email.contains("@") else {
            errorMessage = "Enter a valid email."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be >= 6 characters."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        
        isLoading = true
        Task {
            do {
                _ = try await AuthService.shared.signUp(name: name, email: email, password: password)
                await GuestDataMigrator.migrate()
                isLoading = false
                onSuccess()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func clearState() {
        email = ""
        password = ""
        name = ""
        errorMessage = nil
        isLoading = false
    }
}
