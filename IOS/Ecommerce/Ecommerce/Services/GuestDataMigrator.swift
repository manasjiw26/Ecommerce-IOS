import Foundation

/// Runs after a successful login or sign-up to transfer guest-session data
/// into the newly authenticated account context.
///
/// ### What gets migrated
/// | Data              | Strategy |
/// |-------------------|----------|
/// | **Cart**          | In-memory only — `CartManager` items already survive in-process, nothing to move |
/// | **Saved For Later** | In-memory only — same pattern |
/// | **Registries**    | Call `MockRegistryService.fetchRegistriesFromBackend()` to pull server-side registries now that a real user ID exists |
/// | **Orders**        | Call `OrderManager.shared.fetchOrders()` to load the authenticated user's order history |
///
enum GuestDataMigrator {

    @MainActor
    static func migrate() async {
        guard !AuthSession.shared.isGuest else { return }

        // 1. Load server-side registries for the signed-in user
        do {
            try await MockRegistryService.shared.fetchRegistriesFromBackend()
        } catch {
            print("⚠️ GuestDataMigrator: registry fetch failed — \(error.localizedDescription)")
        }

        // 2. Refresh order history
        await OrderManager.shared.fetchOrders()

        print("✅ GuestDataMigrator: migration complete for user \(AuthSession.shared.currentUser?.id ?? "unknown")")
    }
}
