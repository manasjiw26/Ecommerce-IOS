import SwiftUI

struct RegistrySearchView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchQuery = ""
    @State private var joinCodeQuery = ""
    @State private var joinError: String? = nil
    @State private var isJoining = false

    @State private var nameSearchResults: [MockRegistryExtended] = []
    @State private var isSearching = false
    @State private var searchError: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil
    
    // Callback when a registry is selected
    let onSelectRegistry: (MockRegistryExtended) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // MARK: - Join with Sharing Code Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("JOIN WITH SHARING CODE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .kerning(1.2)
                    
                    HStack(spacing: 8) {
                        TextField("Enter Registry Code (e.g. EMMA-WEDDING)", text: $joinCodeQuery)
                            .font(.system(size: 13))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color(UIColor.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: joinCodeQuery) { _ in
                                joinError = nil
                            }
                        
                        Button(action: {
                            Task {
                                do {
                                    joinError = nil
                                    isJoining = true
                                    let trimmed = joinCodeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else {
                                        isJoining = false
                                        return
                                    }

                                    if let found = try await MockRegistryService.shared.joinRegistryByCode(code: trimmed) {
                                        await MainActor.run {
                                            isJoining = false
                                            joinCodeQuery = ""
                                            onSelectRegistry(found)
                                            dismiss()
                                        }
                                    } else {
                                        await MainActor.run {
                                            isJoining = false
                                            joinError = "No registry found for that code. Check and try again."
                                        }
                                    }
                                } catch {
                                    await MainActor.run {
                                        isJoining = false
                                        joinError = "No registry found for that code. Check and try again."
                                    }
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                if isJoining {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.65)
                                }
                                Text(isJoining ? "Joining" : "Join")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 18)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isJoining || joinCodeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if let err = joinError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                Divider().padding(.horizontal, 16)
                
                // Search Bar
                VStack(alignment: .leading, spacing: 8) {
                    Text("SEARCH REGISTRANT NAME")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .kerning(1.2)
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search by registrant name...", text: $searchQuery)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 16)
                .onChange(of: searchQuery) { newValue in
                    searchError = nil
                    searchTask?.cancel()

                    let q = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard q.count >= 2 else {
                        nameSearchResults = []
                        isSearching = false
                        return
                    }

                    searchTask = Task {
                        // simple debounce to avoid spamming requests
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        if Task.isCancelled { return }

                        await MainActor.run { isSearching = true }
                        do {
                            let results = try await RegistryService.shared.searchRegistriesByName(q)
                            let currentUserId = AuthSession.shared.currentUser?.id
                            let mapped = results.map { $0.toExtended(currentUserId: currentUserId) }
                            await MainActor.run {
                                nameSearchResults = mapped
                                isSearching = false
                            }
                        } catch {
                            await MainActor.run {
                                searchError = "Search failed. Please try again."
                                nameSearchResults = []
                                isSearching = false
                            }
                        }
                    }
                }
                
                // Search Results
                List {
                    if let err = searchError {
                        Text(err)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.top, 12)
                            .listRowSeparator(.hidden)
                    } else if isSearching {
                        HStack {
                            ProgressView()
                            Text("Searching...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 12)
                        .listRowSeparator(.hidden)
                    } else if nameSearchResults.isEmpty {
                        Text(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 ? "Type at least 2 characters to search." : "No registries found.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 24)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(nameSearchResults) { reg in
                            Button(action: {
                                if let email = AuthSession.shared.currentUser?.email {
                                    Task {
                                        do {
                                            try await RegistryService.shared.addCollaborator(registryId: reg.id, email: email, role: "viewer")
                                        } catch {
                                            print("Warning: Failed to add collaborator for searched registry - \(error)")
                                        }
                                    }
                                }
                                onSelectRegistry(reg)
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(reg.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("\(reg.type)  •  \(reg.location)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Find a Registry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.primary)
                        .fontWeight(.bold)
                }
            }
        }
    }
}
