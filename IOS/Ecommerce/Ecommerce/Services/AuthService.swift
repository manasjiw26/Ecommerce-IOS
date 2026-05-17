import Foundation
import Combine

// MARK: - Auth Models

struct AuthUser: Codable {
    let id: String
    let email: String
    let name: String?
}

struct AuthResponse: Codable {
    let user: AuthUser
    let access_token: String?
}

struct AuthError: Codable {
    let error: String
}

// MARK: - Auth Session (singleton)

/// Manages the current authentication state.
/// The app always starts in "guest" mode (`currentUser == nil`).
/// A user is considered a guest whenever `isGuest` is `true`.
class AuthSession: ObservableObject {
    static let shared = AuthSession()

    @Published var currentUser: AuthUser? = nil
    @Published var accessToken: String? = nil

    private let userKey  = "auth_user"
    private let tokenKey = "auth_token"

    /// `true` when no real account is signed in.
    var isGuest: Bool { currentUser == nil }

    init() {
        loadPersistedSession()
    }

    // MARK: Persist a real authenticated session

    func save(user: AuthUser, token: String?) {
        currentUser  = user
        accessToken  = token

        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userKey)
        }
        if let token = token {
            UserDefaults.standard.set(token, forKey: tokenKey)
        }
        UserDefaults.standard.set(user.email, forKey: "userEmail")
        UserDefaults.standard.set(user.name ?? "", forKey: "userName")
    }

    // MARK: Sign out → back to guest (no forced onboarding)

    func signOut() {
        currentUser  = nil
        accessToken  = nil
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "userName")

        // Post logout notification so any listening view can react
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }

    // MARK: Private helpers

    private func loadPersistedSession() {
        guard let data = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONDecoder().decode(AuthUser.self, from: data) else {
            // No session stored → stay as guest
            return
        }
        currentUser = user
        accessToken = UserDefaults.standard.string(forKey: tokenKey)
    }
}

// MARK: - Auth Service (network calls)

class AuthService {
    static let shared = AuthService()
    private let baseURL = APIService.baseURL

    func signUp(name: String, email: String, password: String) async throws -> AuthUser {
        guard let url = URL(string: "\(baseURL)/auth/signup") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "name": name, "email": email, "password": password
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if http.statusCode != 200 {
            let errObj = try? JSONDecoder().decode(AuthError.self, from: data)
            throw NSError(domain: "Auth", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: errObj?.error ?? "Sign up failed"])
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        await MainActor.run {
            AuthSession.shared.save(user: authResponse.user, token: authResponse.access_token)
        }
        return authResponse.user
    }

    func login(email: String, password: String) async throws -> AuthUser {
        guard let url = URL(string: "\(baseURL)/auth/login") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email, "password": password
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if http.statusCode != 200 {
            let errObj = try? JSONDecoder().decode(AuthError.self, from: data)
            throw NSError(domain: "Auth", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: errObj?.error ?? "Login failed"])
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        await MainActor.run {
            AuthSession.shared.save(user: authResponse.user, token: authResponse.access_token)
        }
        return authResponse.user
    }
}
