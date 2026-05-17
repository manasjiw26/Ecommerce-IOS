import SwiftUI

struct RegistrySearchView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchQuery = ""
    @State private var joinCodeQuery = ""
    
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
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(6)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        
                        Button(action: {
                            Task {
                                do {
                                    if let found = try await MockRegistryService.shared.joinRegistryByCode(code: joinCodeQuery) {
                                        await MainActor.run {
                                            joinCodeQuery = ""
                                            onSelectRegistry(found)
                                            dismiss()
                                        }
                                    }
                                } catch {
                                    print("Error joining registry by code: \(error)")
                                }
                            }
                        }) {
                            Text("Join")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.black)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(joinCodeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Divider().padding(.horizontal, 20)
                
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
                    .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                
                // Search Results
                List {
                    let filtered = MockRegistryService.shared.registries.filter {
                        searchQuery.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchQuery)
                    }
                    
                    if filtered.isEmpty {
                        Text("No registries found.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 24)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(filtered) { reg in
                            Button(action: {
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
