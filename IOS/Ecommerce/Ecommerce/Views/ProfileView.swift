import SwiftUI

struct ProfileView: View {
    var onLogout: (() -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var cartManager: CartManager
    @State private var showLogoutAlert = false
    
    let name = UserDefaults.standard.string(forKey: "userName") ?? "Guest"
    let email = UserDefaults.standard.string(forKey: "userEmail") ?? "guest@shopease.com"
    let memberSince = "May 2026"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Avatar & Name
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.black, Color.gray.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 90, height: 90)
                        Text(String(name.split(separator: " ").compactMap { $0.first }.map { String($0) }.joined().prefix(2)).uppercased())
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text(name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Member since \(memberSince)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Info Card
                VStack(spacing: 0) {
                    ProfileInfoRow(icon: "envelope.fill", iconColor: .blue, label: "Email", value: email)
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
                
                // App version
                Text("ShopEase  •  v1.0.0")
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
                cartManager.removeAll()
                OrderManager.shared.clearAll()
                UserDefaults.standard.set(false, forKey: "isLoggedIn")
                UserDefaults.standard.removeObject(forKey: "userEmail")
                UserDefaults.standard.removeObject(forKey: "userName")
                presentationMode.wrappedValue.dismiss()
                onLogout?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to log out? Your cart and order history will be cleared.")
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
    }
}
