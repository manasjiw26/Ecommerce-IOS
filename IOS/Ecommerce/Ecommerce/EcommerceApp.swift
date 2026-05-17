import SwiftUI

@main
struct EcommerceApp: App {

    // MARK: - Global state objects
    @StateObject private var cartManager    = CartManager()
    @StateObject private var productViewModel = ProductViewModel()
    @StateObject private var aiPresence     = AIPresenceManager()
    @StateObject private var savedVM        = SavedForLaterViewModel()
    @StateObject private var addressBook    = AddressBookViewModel()
    @StateObject private var authSession    = AuthSession.shared

    // MARK: - Splash
    @State private var splashDone = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if splashDone {
                    // ── Main app — always visible, guest or signed-in ──
                    ContentView()
                        .environmentObject(cartManager)
                        .environmentObject(productViewModel)
                        .environmentObject(authSession)
                        .environmentObject(aiPresence)
                        .environmentObject(savedVM)
                        .environmentObject(addressBook)
                        .transition(.opacity)
                } else {
                    // ── Splash screen ──
                    SplashScreenView()
                        .transition(.opacity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    splashDone = true
                                }
                            }
                        }
                }
            }
            // Deep-link: registry share token
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

// MARK: - Notification names

extension Notification.Name {
    static let userDidLogout      = Notification.Name("userDidLogout")
    static let requireAuth        = Notification.Name("requireAuth")
    static let openRegistryToken  = Notification.Name("openRegistryToken")
}
