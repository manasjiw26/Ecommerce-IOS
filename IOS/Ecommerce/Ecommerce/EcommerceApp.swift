import SwiftUI

@main
struct EcommerceApp: App {
    @StateObject private var cartManager = CartManager()
    @StateObject private var productViewModel = ProductViewModel()
    @StateObject private var aiPresence = AIPresenceManager()
    @State private var isLoggedIn: Bool = UserDefaults.standard.bool(forKey: "isLoggedIn")
    @State private var showLogin = false
    @State private var showSignUp = false
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Always show main app — products visible to all
                ContentView()
                    .environmentObject(cartManager)
                    .environmentObject(productViewModel)
                    .environmentObject(AuthSession.shared)
                    .environmentObject(aiPresence)

                // Onboarding overlays on top when triggered
                if showSignUp {
                    SignUpView(
                        onSignUpSuccess: {
                            withAnimation { isLoggedIn = true; showSignUp = false; showOnboarding = false }
                        },
                        onBack: { withAnimation { showSignUp = false } }
                    )
                    .transition(.move(edge: .trailing))
                    .zIndex(3)
                } else if showLogin {
                    LoginView(
                        onLoginSuccess: {
                            withAnimation { isLoggedIn = true; showLogin = false; showOnboarding = false }
                        },
                        onBack: { withAnimation { showLogin = false } }
                    )
                    .transition(.move(edge: .trailing))
                    .zIndex(2)
                } else if showOnboarding {
                    OnboardingView(
                        onLogin: { withAnimation { showLogin = true } },
                        onSignUp: { withAnimation { showSignUp = true } }
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
                withAnimation {
                    isLoggedIn = false
                    showLogin = false
                    showSignUp = false
                    showOnboarding = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .requireAuth)) { _ in
                if !isLoggedIn {
                    withAnimation { showOnboarding = true }
                }
            }
            .onOpenURL { url in
                if url.pathComponents.contains("r"), let token = url.pathComponents.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(name: .openRegistryToken, object: token)
                    }
                }
            }
        }
    }
}

extension Notification.Name {
    static let userDidLogout = Notification.Name("userDidLogout")
    static let requireAuth   = Notification.Name("requireAuth")
    static let openRegistryToken = Notification.Name("openRegistryToken")
}

