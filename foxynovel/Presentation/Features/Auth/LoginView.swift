//
//  LoginView.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Logo/Header
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.accent)

                        Text("FoxyNovel")
                            .typography(Typography.displayMedium)

                        Text("Descubre tu próxima aventura")
                            .typography(Typography.bodyLarge, color: .textSecondary)
                    }
                    .padding(.top, Spacing.xxl)

                    // Form
                    VStack(spacing: Spacing.md) {
                        CustomTextField(
                            placeholder: "Email",
                            text: $viewModel.email,
                            keyboardType: .emailAddress,
                            icon: "envelope"
                        )

                        CustomTextField(
                            placeholder: "Contraseña",
                            text: $viewModel.password,
                            isSecure: true,
                            icon: "lock"
                        )

                        // Error Message
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .typography(Typography.bodySmall, color: .error)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Login Button
                        PrimaryButton("Iniciar Sesión", isLoading: viewModel.isLoading) {
                            Task {
                                await viewModel.login()
                            }
                        }
                        .padding(.top, Spacing.md)

                        // Register Link
                        HStack {
                            Text("¿No tienes cuenta?")
                                .typography(Typography.bodyMedium, color: .textSecondary)

                            Button("Regístrate") {
                                // Navigate to register
                            }
                            .typography(Typography.bodyMedium, color: .accent)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
            }
            .background(Color.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .onChange(of: viewModel.isAuthenticated) { oldValue, newValue in
                if newValue {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    LoginView()
}
