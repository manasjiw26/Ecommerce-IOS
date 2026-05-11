//
//  ContentView.swift
//  Ecommerce
//
//  Created by Apple on 03/05/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var cartManager: CartManager
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ProductListView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Shop")
                }
                .tag(0)
            
            NavigationStack {
                CartView()
            }
            .tabItem {
                Image(systemName: "cart.fill")
                Text("Cart")
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
        }
        .tint(.primary)
        .task {
            await OrderManager.shared.fetchOrders()
        }
    }
}

#Preview {
    ContentView()
}
