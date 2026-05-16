import SwiftUI

struct RegistryCoordinatorView: View {
    @StateObject private var viewModel = RegistryViewModel()
    @EnvironmentObject var authSession: AuthSession
    
    var body: some View {
        NavigationStack {
            if authSession.currentUser == nil {
                VStack(spacing: 20) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Please log in to create or view your Registry.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .navigationTitle("Registry")
            } else {
                Group {
                    if viewModel.isLoading && viewModel.currentRegistry == nil {
                        ProgressView("Loading Registry...")
                    } else if viewModel.currentRegistry != nil {
                        RegistryDashboardView(viewModel: viewModel)
                    } else {
                        CreateRegistryView(viewModel: viewModel)
                    }
                }
                .navigationTitle("Registry")
                .task {
                    await viewModel.fetchUserRegistry()
                }
            }
        }
    }
}
