//
//  ProfileView.swift
//  foxynovel
//
//  Created by Claude on 20/10/25.
//

import SwiftUI
import GoogleSignInSwift

struct ProfileView: View {
    @EnvironmentObject private var viewModel: ProfileViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.isAuthenticated, let user = viewModel.user {
                    authenticatedView(user: user)
                } else {
                    unauthenticatedView
                }
            }
            .navigationTitle("Perfil")
            .alert("Sesión Expirada", isPresented: $viewModel.showSessionExpiredAlert) {
                Button("Aceptar", role: .cancel) {
                    // Alert will dismiss automatically
                }
            } message: {
                Text("Tu sesión ha expirado. Por favor, inicia sesión nuevamente para continuar.")
            }
        }
    }

    private var unauthenticatedView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.accent)

            Text("Inicia sesión para continuar")
                .typography(Typography.titleMedium)

            Text("Accede a tu biblioteca, favoritos y preferencias")
                .typography(Typography.bodyMedium, color: .textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.screenPadding)

            // Google Sign-In Button
            Button {
                Task {
                    await viewModel.signInWithGoogle()
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                    Text("Continuar con Google")
                        .typography(Typography.bodyMedium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.accent)
                .cornerRadius(CornerRadius.md)
            }
            .padding(.horizontal, Spacing.screenPadding)

            if let error = viewModel.errorMessage {
                Text(error)
                    .typography(Typography.bodySmall, color: .error)
                    .padding(.horizontal, Spacing.screenPadding)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, Spacing.lg)
    }

    private func authenticatedView(user: User) -> some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Profile Header
                VStack(spacing: Spacing.md) {
                    if let imageUrl = user.profileImage, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.accent)
                    }

                    Text(user.username ?? user.email)
                        .typography(Typography.titleLarge)

                    Text(user.email)
                        .typography(Typography.bodyMedium, color: .textSecondary)
                }
                .padding(.top, Spacing.lg)

                // Menu Options
                VStack(spacing: 0) {
                    profileMenuItem(icon: "book.fill", title: "Biblioteca", action: {})
                    Divider()
                    profileMenuItem(icon: "heart.fill", title: "Favoritos", action: {})
                    Divider()
                    profileMenuItem(icon: "bell.fill", title: "Notificaciones", action: {})
                    Divider()
                    profileMenuItem(icon: "gear", title: "Configuración", action: {})
                }
                .background(Color.surface)
                .cornerRadius(CornerRadius.lg)
                .padding(.horizontal, Spacing.screenPadding)

                // Sign Out Button
                Button {
                    Task {
                        await viewModel.signOut()
                    }
                } label: {
                    Text("Cerrar sesión")
                        .typography(Typography.bodyMedium)
                        .foregroundColor(.error)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.surface)
                        .cornerRadius(CornerRadius.md)
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.top, Spacing.md)
            }
        }
        .refreshable {
            await viewModel.refreshUserData()
        }
    }

    private func profileMenuItem(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .foregroundColor(.accent)
                    .frame(width: 24)

                Text(title)
                    .typography(Typography.bodyMedium)
                    .foregroundColor(.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.md)
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Cargando...")
                .typography(Typography.bodyMedium, color: .textSecondary)
                .padding(.top, Spacing.sm)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(ProfileViewModel())
}
