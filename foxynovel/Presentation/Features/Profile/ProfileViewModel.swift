//
//  ProfileViewModel.swift
//  foxynovel
//
//  Created by Claude on 20/10/25.
//

import SwiftUI
import Combine
import FirebaseMessaging
import OSLog

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showSessionExpiredAlert: Bool = false

    private let authRepository: AuthRepositoryProtocol
    private let tokenManager: TokenManager
    private var cancellables = Set<AnyCancellable>()

    init(authRepository: AuthRepositoryProtocol = DIContainer.shared.authRepository,
         tokenManager: TokenManager = TokenManager.shared) {
        self.authRepository = authRepository
        self.tokenManager = tokenManager

        setupNotificationObservers()
        checkAuthStatus()
    }

    /// Setup observers for authentication events
    private func setupNotificationObservers() {
        // Observe session expiration events
        NotificationCenter.default.publisher(for: .sessionExpired)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleSessionExpired(notification: notification)
            }
            .store(in: &cancellables)
    }

    /// Handle session expiration notification
    private func handleSessionExpired(notification: Notification) {
        Logger.authLog("🚪", "[ProfileViewModel] Session expired notification received")

        // Update UI state
        user = nil
        isAuthenticated = false
        showSessionExpiredAlert = true

        // Log reason for analytics
        if let reason = notification.userInfo?["reason"] as? String {
            Logger.debug("[ProfileViewModel] Session expired reason: \(reason)", category: Logger.auth)
        }
    }

    deinit {
        cancellables.removeAll()
    }

    func checkAuthStatus() {
        Logger.authLog("🔍", "[ProfileViewModel] Checking auth status...")

        isAuthenticated = authRepository.isAuthenticated()

        Logger.authLog("🔍", "[ProfileViewModel] Is authenticated: \(isAuthenticated)")

        if isAuthenticated {
            // Load user from cache - ALWAYS available after login
            user = UserStorage.loadUser()

            if let user = user {
                Logger.authLog("✅", "[ProfileViewModel] User loaded from cache: \(user.email)")
            } else {
                Logger.debug("[ProfileViewModel] No cached user found - user needs to login", category: Logger.auth)
            }

            // NO automatic refresh - user controls updates via pull-to-refresh
        }
    }

    /// Force refresh user data (for pull-to-refresh)
    /// Currently reloads from cache. In the future, you can call a server endpoint here
    /// if you need to fetch updated data (e.g., after profile edit from another device)
    func refreshUserData() async {
        Logger.authLog("🔄", "[ProfileViewModel] Manual refresh requested")

        isLoading = true

        // Simply reload from cache (instant)
        user = UserStorage.loadUser()

        // TODO: In the future, if you need fresh data from server:
        // do {
        //     user = try await authRepository.fetchUserProfileFromServer()
        // } catch {
        //     // Keep current cached user on error
        // }

        isLoading = false

        Logger.authLog("✅", "[ProfileViewModel] Refresh completed")
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        do {
            let authResponse = try await authRepository.signInWithGoogle()
            user = authResponse.user
            isAuthenticated = true

            Logger.authLog("✅", "[ProfileViewModel] User authenticated: \(authResponse.user.email)")

            // Registrar FCM token después del login
            await registerFCMToken()

        } catch {
            errorMessage = "Error al iniciar sesión: \(error.localizedDescription)"
            Logger.error("[ProfileViewModel] Google Sign-In error: \(error)", category: Logger.auth)
        }

        isLoading = false
    }

    func signOut() async {
        do {
            try await authRepository.logout()
            user = nil
            isAuthenticated = false
            Logger.authLog("✅", "[ProfileViewModel] User signed out successfully")
        } catch {
            errorMessage = "Error al cerrar sesión"
            Logger.error("[ProfileViewModel] Sign out error: \(error)", category: Logger.auth)
        }
    }

    private func loadUserProfile() async {
        Logger.authLog("👤", "[ProfileViewModel] Loading user profile from cache...")

        // getCurrentUser() now only reads from cache (never fails)
        user = try? await authRepository.getCurrentUser()

        if let user = user {
            Logger.authLog("✅", "[ProfileViewModel] User profile loaded: \(user.email)")
        } else {
            Logger.debug("[ProfileViewModel] No cached user - needs login", category: Logger.auth)
        }
    }

    private func registerFCMToken() async {
        #if targetEnvironment(simulator)
        Logger.info("[ProfileViewModel] FCM registration skipped on simulator (simulators don't support APNS)", category: Logger.config)
        Logger.info("[ProfileViewModel] FCM will work automatically on real devices", category: Logger.config)
        return
        #else
        do {
            // Obtener FCM token (requires APNS token to be set first)
            let fcmToken = try await Messaging.messaging().token()
            Logger.authLog("📱", "[ProfileViewModel] FCM Token obtained: \(fcmToken.prefix(20))...")

            // Registrar en backend
            try await authRepository.registerDeviceToken(fcmToken)
            Logger.authLog("✅", "[ProfileViewModel] FCM token registered with backend")
        } catch let error as NSError {
            // Handle FCM-specific errors gracefully
            if error.domain == "com.google.fcm" && error.code == 505 {
                Logger.info("[ProfileViewModel] FCM token not available (APNS token not set yet)", category: Logger.auth)
            } else {
                Logger.error("[ProfileViewModel] Could not register FCM token: \(error.localizedDescription)", category: Logger.auth)
            }
            // Don't block authentication flow if FCM registration fails
        }
        #endif
    }
}
