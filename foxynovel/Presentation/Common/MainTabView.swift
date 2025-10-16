//
//  MainTabView.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView()
                .tabItem {
                    Label("Inicio", systemImage: "house.fill")
                }
                .tag(0)

            // Library Tab
            LibraryView()
                .tabItem {
                    Label("Biblioteca", systemImage: "book.fill")
                }
                .tag(1)

            // Search Tab
            SearchPlaceholderView()
                .tabItem {
                    Label("Buscar", systemImage: "magnifyingglass")
                }
                .tag(2)

            // Profile Tab
            ProfilePlaceholderView()
                .tabItem {
                    Label("Perfil", systemImage: "person.fill")
                }
                .tag(3)
        }
        .accentColor(.accent)
    }
}

// MARK: - Placeholder Views
struct LibraryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "book.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accent)
                Text("Biblioteca")
                    .typography(Typography.titleLarge)
                Text("Próximamente")
                    .typography(Typography.bodyMedium, color: .textSecondary)
            }
            .navigationTitle("Biblioteca")
        }
    }
}

struct SearchPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.accent)
                Text("Buscar")
                    .typography(Typography.titleLarge)
                Text("Próximamente")
                    .typography(Typography.bodyMedium, color: .textSecondary)
            }
            .navigationTitle("Buscar")
        }
    }
}

struct ProfilePlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "person.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accent)
                Text("Perfil")
                    .typography(Typography.titleLarge)
                Text("Próximamente")
                    .typography(Typography.bodyMedium, color: .textSecondary)
            }
            .navigationTitle("Perfil")
        }
    }
}

#Preview {
    MainTabView()
}
