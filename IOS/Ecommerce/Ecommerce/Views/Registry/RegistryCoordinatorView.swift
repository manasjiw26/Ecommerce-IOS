import SwiftUI

struct RegistryCoordinatorView: View {
    @State private var path = NavigationPath()
    @State private var isJoiningFromLink = false
    @State private var joinError: String? = nil
    
    var body: some View {
        NavigationStack(path: $path) {
            RegistryLandingView { selectedRegistry in
                path.append(selectedRegistry)
            }
            .navigationDestination(for: MockRegistryExtended.self) { registry in
                if registry.isOwner {
                    RegistryDashboardView(registry: registry)
                } else {
                    RegistryGuestLandingView(registry: registry)
                }
            }
            .navigationTitle("Registry")
            .navigationBarTitleDisplayMode(.large)
            .overlay {
                if isJoiningFromLink {
                    RegistryLoadingOverlay(message: "Opening Registry...")
                }
            }
            .alert("Registry Error", isPresented: Binding(
                get: { joinError != nil },
                set: { if !$0 { joinError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(joinError ?? "")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRegistryToken)) { notification in
            if let token = notification.object as? String {
                Task {
                    await MainActor.run { isJoiningFromLink = true; joinError = nil }
                    do {
                        if let registry = try await MockRegistryService.shared.joinRegistryByCode(code: token) {
                            await MainActor.run {
                                isJoiningFromLink = false
                                path.append(registry)
                            }
                        } else {
                            await MainActor.run {
                                isJoiningFromLink = false
                                joinError = "Could not find registry for that link."
                            }
                        }
                    } catch {
                        await MainActor.run {
                            isJoiningFromLink = false
                            joinError = error.localizedDescription
                        }
                    }
                }
            }
        }
    }
}
