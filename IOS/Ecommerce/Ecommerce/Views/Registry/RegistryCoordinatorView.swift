import SwiftUI

struct RegistryCoordinatorView: View {
    @State private var path = NavigationPath()
    
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
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
