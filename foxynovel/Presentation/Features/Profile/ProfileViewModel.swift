//
//  ProfileViewModel.swift
//  foxynovel
//
//  Created by Claude on 20/10/25.
//

import SwiftUI
import Combine
import FirebaseMessaging

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let authRepository: AuthRepositoryProtocol
    private let tokenManager: TokenManager

    init(authRepository: AuthRepositoryProtocol = DIContainer.shared.authRepository,
         tokenManager: TokenManager = TokenManager.shared) {
        self.authRepository = authRepository
        self.tokenManager = tokenManager

        checkAuthStatus()
    }

    func checkAuthStatus() {
        #if DEBUG
        print("🔍 [ProfileViewModel] Checking auth status...")
        #endif
        isAuthenticated = authRepository.isAuthenticated()
        #if DEBUG
        print("🔍 [ProfileViewModel] Is authenticated: \(isAuthenticated)")
        #endif

        if isAuthenticated {
            // Load user from cache immediately (fast UX)
            user = UserStorage.loadUser()

            #if DEBUG
            if user != nil {
                print("✅ [ProfileViewModel] User loaded from cache: \(user?.email ?? "unknown")")
            }
            #endif

            // Optionally refresh in background if cache is stale
            Task {
                await refreshUserIfNeeded()
            }
        }
    }

    /// Refresh user data from server if cache is stale
    private func refreshUserIfNeeded() async {
        // Only refresh if cache is older than 1 hour
        guard UserStorage.shouldRefreshUserData() else {
            #if DEBUG
            print("ℹ️ [ProfileViewModel] Cache is fresh, skipping server request")
            #endif
            return
        }

        #if DEBUG
        print("🔄 [ProfileViewModel] Cache is stale, refreshing from server...")
        #endif
        await loadUserProfile()
    }

    /// Force refresh user data from server (for pull-to-refresh)
    func refreshUserData() async {
        #if DEBUG
        print("🔄 [ProfileViewModel] Manual refresh requested")
        #endif
        isLoading = true
        await loadUserProfile()
        isLoading = false
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        do {
            let authResponse = try await authRepository.signInWithGoogle()
            user = authResponse.user
            isAuthenticated = true

            #if DEBUG
            print("✅ User authenticated: \(authResponse.user.email)")
            #endif

            // Registrar FCM token después del login
            await registerFCMToken()

        } catch {
            errorMessage = "Error al iniciar sesión: \(error.localizedDescription)"
            #if DEBUG
            print("❌ Google Sign-In error: \(error)")
            #endif
        }

        isLoading = false
    }

    func signOut() async {
        do {
            try await authRepository.logout()
            user = nil
            isAuthenticated = false
            #if DEBUG
            print("✅ User signed out successfully")
            #endif
        } catch {
            errorMessage = "Error al cerrar sesión"
            #if DEBUG
            print("❌ Sign out error: \(error)")
            #endif
        }
    }

    private func loadUserProfile() async {
        #if DEBUG
        print("👤 [ProfileViewModel] Loading user profile...")
        #endif
        do {
            user = try await authRepository.getCurrentUser()
            #if DEBUG
            print("✅ [ProfileViewModel] User profile loaded: \(user?.email ?? "unknown")")
            #endif
        } catch {
            #if DEBUG
            print("❌ [ProfileViewModel] Error loading user profile: \(error)")
            #endif
            // Si falla al cargar el perfil, el token puede haber expirado
            isAuthenticated = false
        }
    }

    private func registerFCMToken() async {
        #if targetEnvironment(simulator)
        print("ℹ️ FCM registration skipped on simulator (simulators don't support APNS)")
        print("ℹ️ FCM will work automatically on real devices")
        return
        #else
        do {
            // Obtener FCM token (requires APNS token to be set first)
            let fcmToken = try await Messaging.messaging().token()
            print("📱 FCM Token obtained: \(fcmToken.prefix(20))...")

            // Registrar en backend
            try await authRepository.registerDeviceToken(fcmToken)
            print("✅ FCM token registered with backend")
        } catch let error as NSError {
            // Handle FCM-specific errors gracefully
            if error.domain == "com.google.fcm" && error.code == 505 {
                print("ℹ️ FCM token not available (APNS token not set yet)")
            } else {
                print("⚠️ Could not register FCM token: \(error.localizedDescription)")
            }
            // Don't block authentication flow if FCM registration fails
        }
        #endif
    }
}
