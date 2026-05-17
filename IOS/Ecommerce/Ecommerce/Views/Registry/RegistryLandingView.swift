import SwiftUI

struct RegistryLandingView: View {
    @State private var registries = MockRegistryService.shared.registries
    @State private var showingWizard = false
    @State private var showingSearch = false
    @State private var joinCodeQuery = ""
    
    // Callbacks to communicate navigation changes back to Coordinator
    let onSelectRegistry: (MockRegistryExtended) -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Premium Hero Section
                ZStack(alignment: .bottomLeading) {
                    CachedImageView(urlString: "https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&w=800&q=80") { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.1))
                    }
                    .frame(height: 200)
                    .clipped()
                    .overlay(Color.black.opacity(0.45))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("THE GIFT REGISTRY")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.8))
                            .kerning(1.5)
                        
                        Text("Curate your perfect home together.")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(20)
                }
                
                // MARK: - Primary Actions
                HStack(spacing: 12) {
                    Button(action: { showingWizard = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Create Registry")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showingSearch = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12, weight: .bold))
                            Text("Find Registry")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                
                // MARK: - My Registries
                let owned = registries.filter { $0.isOwner }
                if !owned.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("My Registries")
                            .font(.headline)
                            .padding(.horizontal, 20)
                        
                        ForEach(owned) { reg in
                            RegistryCardRow(registry: reg) {
                                onSelectRegistry(reg)
                            }
                        }
                    }
                }
                
                // MARK: - Registries I'm Gifting
                let gifting = registries.filter { !$0.isOwner }
                if !gifting.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Registries I'm Gifting")
                            .font(.headline)
                            .padding(.horizontal, 20)
                        
                        ForEach(gifting) { reg in
                            RegistryCardRow(registry: reg) {
                                onSelectRegistry(reg)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .onAppear {
            // Dynamically refresh lists on screen appearance
            Task {
                try? await MockRegistryService.shared.fetchRegistriesFromBackend()
                await MainActor.run {
                    registries = MockRegistryService.shared.registries
                }
            }
        }
        .sheet(isPresented: $showingWizard) {
            RegistryWizardView { newReg in
                Task {
                    do {
                        let created = try await MockRegistryService.shared.createRegistry(
                            name: newReg.name,
                            type: newReg.type,
                            date: newReg.date,
                            location: newReg.location
                        )
                        await MainActor.run {
                            registries = MockRegistryService.shared.registries
                            onSelectRegistry(created)
                        }
                    } catch {
                        print("Error creating registry: \(error)")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            RegistrySearchView { selectedReg in
                onSelectRegistry(selectedReg)
            }
        }
    }
}

// MARK: - Components

struct RegistryCardRow: View {
    let registry: MockRegistryExtended
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                CachedImageView(urlString: registry.bannerImageUrl) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.1))
                }
                .frame(width: 80, height: 60)
                .cornerRadius(8)
                .clipped()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(registry.name)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("\(registry.type)  •  \(registry.date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(registry.itemsCount) items")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(12)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }
}
