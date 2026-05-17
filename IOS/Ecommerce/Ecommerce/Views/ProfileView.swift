import SwiftUI

struct ProfileView: View {
    var onLogout: (() -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var addressBook: AddressBookViewModel
    @ObservedObject private var authSession = AuthSession.shared
    @State private var showLogoutAlert  = false
    @State private var showAuthPrompt   = false

    private var displayName: String {
        authSession.currentUser?.name ?? "Guest"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
            // Avatar & Name
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: authSession.isGuest
                                ? [Color.gray.opacity(0.5), Color.gray.opacity(0.3)]
                                : [Color.black, Color.gray.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 90, height: 90)
                    if authSession.isGuest {
                        Image(systemName: "person")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundColor(.white)
                    } else {
                        Text(
                            String(
                                displayName.split(separator: " ")
                                    .compactMap { $0.first }
                                    .map { String($0) }
                                    .joined()
                                    .prefix(2)
                            ).uppercased()
                        )
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    }
                }
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                if authSession.isGuest {
                    Text("Browsing as Guest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Member since May 2026")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 20)

            // Guest banner — sign in CTA
            if authSession.isGuest {
                VStack(spacing: 12) {
                    Text("Sign in to unlock your full Shop Ease experience — order tracking, registries, and more.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    HStack(spacing: 12) {
                        Button(action: { showAuthPrompt = true }) {
                            Text("Log In")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.black)
                                .cornerRadius(12)
                        }
                        Button(action: { showAuthPrompt = true }) {
                            Text("Create Account")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 1))
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                .padding(.horizontal)
                .sheet(isPresented: $showAuthPrompt) {
                    AuthPromptSheet(context: .orders) { presentationMode.wrappedValue.dismiss() }
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.hidden)
                }
            }
                
                // My Account
                VStack(spacing: 0) {
                    NavigationLink(destination: OrderListView()) {
                        ProfileActionRow(icon: "shippingbox.fill", label: "Order History", color: .indigo)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider().padding(.leading, 52)
                    
                    NavigationLink(destination: AddressBookView()) {
                        ProfileActionRow(icon: "map.fill", label: "Address Book", color: .green)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                .padding(.horizontal)
                
                // Preferences
                VStack(spacing: 0) {
                    ProfileActionRow(icon: "bell.fill", label: "Notifications", color: .orange)
                    Divider().padding(.leading, 52)
                    ProfileActionRow(icon: "lock.fill", label: "Privacy", color: .gray)
                    Divider().padding(.leading, 52)
                    ProfileActionRow(icon: "questionmark.circle.fill", label: "Help & Support", color: .purple)
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                .padding(.horizontal)
                
                // Logout Button
                if !authSession.isGuest {
                    Button(action: { showLogoutAlert = true }) {
                        HStack {
                            Image(systemName: "arrow.backward.circle.fill")
                                .foregroundColor(.red)
                            Text("Log Out")
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal)
                }
                
                Text("Shop Ease  •  v1.0.0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 32)
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .alert("Log Out", isPresented: $showLogoutAlert) {
            Button("Log Out", role: .destructive) {
                AuthSession.shared.signOut()
                cartManager.removeAll()
                OrderManager.shared.clearAll()
                presentationMode.wrappedValue.dismiss()
                onLogout?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to log out? You'll continue as a guest.")
        }
    }
}

struct ProfileInfoRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(iconColor)
                .cornerRadius(8)
                .padding(.leading, 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(.vertical, 14)
    }
}

struct ProfileActionRow: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(color)
                .cornerRadius(8)
                .padding(.leading, 16)
            
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
                .padding(.trailing, 16)
        }
        .padding(.vertical, 14)
    }
}

#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(CartManager())
            .environmentObject(AddressBookViewModel())
    }
}

// MARK: - Address Book View
struct AddressBookView: View {
    @EnvironmentObject var addressBook: AddressBookViewModel
    @State private var showAddSheet = false
    @State private var editingAddress: Address? = nil
    @State private var showEditSheet = false

    var body: some View {
        List {
            ForEach(addressBook.addresses.indices, id: \.self) { idx in
                let address: Address = addressBook.addresses[idx]
                AddressRow(
                    address: address,
                    isSelected: addressBook.selectedAddressId == address.id,
                    onTap: { addressBook.select(address.id) },
                    onEdit: { editingAddress = address; showEditSheet = true },
                    onDelete: { addressBook.delete(address.id) }
                )
            }
        }
        .navigationTitle("Address Book")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddressEditSheet(
                address: Address(label: "", fullName: "", phone: "", line1: "", line2: "", city: "", state: "", zip: ""),
                onSave: { saved in
                    addressBook.upsert(saved)
                    addressBook.select(saved.id)
                },
                onCancel: {}
            )
        }
        .sheet(isPresented: $showEditSheet) {
            if let addr = editingAddress {
                AddressEditSheet(
                    address: addr,
                    onSave: { updated in
                        addressBook.upsert(updated)
                    },
                    onCancel: {}
                )
            }
        }
    }
}

// MARK: - Address Row (isolated to fix type inference in ForEach)
private struct AddressRow: View {
    let address: Address
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(address.label)
                    .font(.headline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            Text(address.fullName)
                .font(.subheadline)
            if !address.line1.isEmpty {
                Text(address.line2.isEmpty ? address.line1 : "\(address.line1), \(address.line2)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if !address.city.isEmpty {
                Text("\(address.city), \(address.state) \(address.zip)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if !address.phone.isEmpty {
                Text(address.phone)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}

