//
//  ContentView.swift
//  Ecommerce
//
//  Created by Apple on 03/05/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showChat = false
    @State private var chatPulse = false
    @EnvironmentObject var cartManager: CartManager
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                ProductListView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Shop")
                    }
                    .tag(0)
                
                NavigationStack {
                    BagView()
                }
                .tabItem {
                    Image(systemName: "bag.fill")
                    Text("Bag")
                }
                .badge(cartManager.items.count)
                .tag(1)

                NavigationStack {
                    OrderListView()
                        .navigationTitle("Orders")
                }
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("Orders")
                }
                .tag(2)
                
                RegistryCoordinatorView()
                    .tabItem {
                        Image(systemName: "gift.fill")
                        Text("Registry")
                    }
                    .tag(3)
            }
            .tint(.primary)
            
            // Floating chat button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        showChat = true
                    }) {
                        ZStack {
                            // Pulse ring
                            Circle()
                                .fill(Color.black.opacity(0.12))
                                .frame(width: 70, height: 70)
                                .scaleEffect(chatPulse ? 1.25 : 1.0)
                                .opacity(chatPulse ? 0.0 : 0.6)
                                .animation(
                                    .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                                    value: chatPulse
                                )

                            // Main button
                            Circle()
                                .fill(Color.black)
                                .frame(width: 58, height: 58)
                                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)

                            Image(systemName: "sparkles")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 90)
                }
            }
        }
        .sheet(isPresented: $showChat) {
            ChatView()
        }
        .task {
            await OrderManager.shared.fetchOrders()
            chatPulse = true
        }
    }
}

#Preview {
    ContentView()
}
