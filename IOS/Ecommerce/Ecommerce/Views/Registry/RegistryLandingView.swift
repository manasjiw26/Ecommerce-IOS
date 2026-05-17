import SwiftUI

struct RegistryLandingView: View {
    @ObservedObject private var service = MockRegistryService.shared
    @State private var showingWizard = false
    @State private var showingSearch = false
    @State private var isLoadingRegistries = false
    @State private var isCreatingRegistry = false
    @State private var loadError: String? = nil
    @State private var hasFetchedOnce = false
    
    // Callbacks to communicate navigation changes back to Coordinator
    let onSelectRegistry: (MockRegistryExtended) -> Void
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                // MARK: - Premium Hero Section
                ZStack(alignment: .bottomLeading) {
                    CachedImageView(urlString: "https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&w=800&q=80") { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.1))
                    }
                    .frame(height: 200)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.6), Color.black.opacity(0.15)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    
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
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showingSearch = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12, weight: .bold))
                            Text("Find Registry")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                    if isLoadingRegistries && service.registries.isEmpty {
                        RegistryInlineLoadingView(message: "Loading registries...")
                    } else if let loadError, service.registries.isEmpty {
                        VStack(spacing: 12) {
                            Text(loadError)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Retry") {
                                Task { await loadRegistries() }
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    } else {
                        // MARK: - My Registries
                        let owned = service.registries.filter { $0.isOwner }
                        if !owned.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("My Registries")
                                    .font(.headline)
                                    .padding(.horizontal, 16)

                                ForEach(owned) { reg in
                                    RegistryCardRow(registry: reg) {
                                        onSelectRegistry(reg)
                                    }
                                }
                            }
                        }

                        // MARK: - Registries I'm Gifting
                        let gifting = service.registries.filter { !$0.isOwner }
                        if !gifting.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Registries I'm Gifting")
                                    .font(.headline)
                                    .padding(.horizontal, 16)

                                ForEach(gifting) { reg in
                                    RegistryCardRow(registry: reg) {
                                        onSelectRegistry(reg)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .refreshable {
                await loadRegistries()
            }

            if isCreatingRegistry {
                RegistryLoadingOverlay(message: "Creating registry...")
            }
        }
        .task {
            if !hasFetchedOnce {
                await loadRegistries()
                hasFetchedOnce = true
            }
        }
        .sheet(isPresented: $showingWizard) {
            RegistryWizardView { newReg in
                Task {
                    do {
                        await MainActor.run { isCreatingRegistry = true }
                        let created = try await MockRegistryService.shared.createRegistry(
                            name: newReg.name,
                            type: newReg.type,
                            isoDate: newReg.isoDate,
                            location: newReg.location
                        )
                        await MainActor.run {
                            isCreatingRegistry = false
                            onSelectRegistry(created)
                        }
                    } catch {
                        await MainActor.run {
                            isCreatingRegistry = false
                            loadError = error.localizedDescription
                        }
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

    @MainActor
    private func loadRegistries() async {
        isLoadingRegistries = true
        loadError = nil
        do {
            try await service.fetchRegistriesFromBackend()
        } catch {
            loadError = "Could not load registries. Please try again."
        }
        isLoadingRegistries = false
    }
}

// MARK: - Components

struct RegistryCardRow: View {
    let registry: MockRegistryExtended
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                CachedImageView(urlString: registry.bannerImageUrl) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.08))
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(registry.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(registry.type)  •  \(registry.date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text("\(registry.itemsCount) item\(registry.itemsCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(14)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}
