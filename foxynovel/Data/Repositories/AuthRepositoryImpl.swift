//
//  AuthRepositoryImpl.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation
import UIKit
import GoogleSignIn
import FirebaseMessaging
import OSLog

final class AuthRepositoryImpl: AuthRepositoryProtocol {
    private let networkClient: NetworkClientProtocol
    private let tokenManager: TokenProvider

    init(
        networkClient: NetworkClientProtocol,
        tokenManager: TokenProvider
    ) {
        self.networkClient = networkClient
        self.tokenManager = tokenManager
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let endpoint = AuthEndpoints.login(email: email, password: password)
        let apiResponse: ApiResponse<AuthResponseDTO> = try await networkClient.request(endpoint)
        let response = apiResponse.data

        // Save tokens
        tokenManager.saveToken(response.accessToken)
        if let refreshToken = response.refreshToken {
            (tokenManager as? TokenManager)?.saveRefreshToken(refreshToken)
        } else {
            Logger.info("[AuthRepository] ⚠️ Backend did not send refresh token on login - security risk!", category: Logger.auth)
        }

        let authResponse = response.toDomain()

        // Cache user data locally for fast access
        UserStorage.saveUser(authResponse.user)

        // Notify observers that authentication state changed
        NotificationCenter.default.post(name: .authenticationDidChange, object: nil)

        return authResponse
    }

    func register(email: String, password: String, username: String) async throws -> AuthResponse {
        let endpoint = AuthEndpoints.register(email: email, password: password, username: username)
        let apiResponse: ApiResponse<AuthResponseDTO> = try await networkClient.request(endpoint)
        let response = apiResponse.data

        // Save tokens
        tokenManager.saveToken(response.accessToken)
        if let refreshToken = response.refreshToken {
            (tokenManager as? TokenManager)?.saveRefreshToken(refreshToken)
        } else {
            Logger.info("[AuthRepository] ⚠️ Backend did not send refresh token on register - security risk!", category: Logger.auth)
        }

        let authResponse = response.toDomain()

        // Cache user data locally for fast access
        UserStorage.saveUser(authResponse.user)

        // Notify observers that authentication state changed
        NotificationCenter.default.post(name: .authenticationDidChange, object: nil)

        return authResponse
    }

    func logout() async throws {
        tokenManager.removeToken()
        // Clear cached user data on logout
        UserStorage.clearUser()

        // Notify observers that authentication state changed
        NotificationCenter.default.post(name: .authenticationDidChange, object: nil)
    }

    func getCurrentUser() async throws -> User? {
        guard isAuthenticated() else { return nil }

        // Always load from cache - no server calls needed
        // User data is cached after login/register/signIn
        let cachedUser = UserStorage.loadUser()

        if let user = cachedUser {
            Logger.authLog("✅", "[AuthRepository] User loaded from cache: \(user.email)")
        } else {
            Logger.debug("[AuthRepository] No cached user found - user needs to login", category: Logger.auth)
        }

        return cachedUser
    }

    func isAuthenticated() -> Bool {
        return (tokenManager as? TokenManager)?.isTokenValid() ?? false
    }

    func signInWithGoogle() async throws -> AuthResponse {
        // 1. Get presenting view controller
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No presenting view controller found"])
        }

        // 2. Perform Google Sign-In
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

        // 3. Get ID Token
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No ID token received from Google"])
        }

        Logger.authLog("✅", "[AuthRepository] Google Sign-In successful, got ID token")

        // 4. Send to backend
        let endpoint = AuthEndpoints.googleSignInIOS(idToken: idToken)
        let apiResponse: ApiResponse<AuthResponseDTO> = try await networkClient.request(endpoint)
        let response = apiResponse.data

        // 5. Save tokens
        tokenManager.saveToken(response.accessToken)
        if let refreshToken = response.refreshToken {
            (tokenManager as? TokenManager)?.saveRefreshToken(refreshToken)
        } else {
            Logger.info("[AuthRepository] ⚠️ Backend did not send refresh token on Google Sign-In - security risk!", category: Logger.auth)
        }

        Logger.authLog("✅", "[AuthRepository] Backend authentication successful")

        let authResponse = response.toDomain()

        // Cache user data locally for fast access
        UserStorage.saveUser(authResponse.user)

        // Notify observers that authentication state changed
        NotificationCenter.default.post(name: .authenticationDidChange, object: nil)

        return authResponse
    }

    func refreshAccessToken() async throws -> AuthResponse {
        guard let refreshToken = (tokenManager as? TokenManager)?.getRefreshToken() else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No refresh token available"])
        }

        let endpoint = AuthEndpoints.refreshToken(refreshToken: refreshToken)
        let apiResponse: ApiResponse<AuthResponseDTO> = try await networkClient.request(endpoint)
        let response = apiResponse.data

        // Save new tokens
        tokenManager.saveToken(response.accessToken)
        if let newRefreshToken = response.refreshToken {
            (tokenManager as? TokenManager)?.saveRefreshToken(newRefreshToken)
        } else {
            // 🔒 CRITICAL: Backend MUST rotate refresh tokens on each refresh
            Logger.info("[AuthRepository] 🚨 SECURITY ALERT: Backend did not rotate refresh token - possible token reuse attack vector!", category: Logger.auth)
        }

        let authResponse = response.toDomain()

        // Update cached user data
        UserStorage.saveUser(authResponse.user)

        return authResponse
    }

    func registerDeviceToken(_ fcmToken: String) async throws {
        let deviceInfo = RegisterDeviceTokenRequestDTO.DeviceInfo(
            model: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            deviceId: await UIDevice.current.identifierForVendor?.uuidString
        )

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

        let endpoint = NotificationEndpoints.registerDeviceToken(
            token: fcmToken,
            platform: "ios",
            tokenType: "fcm-token",
            appVersion: appVersion,
            deviceInfo: deviceInfo
        )

        // Use a generic response since we don't need the response data
        struct EmptyResponse: Decodable {}
        let _: ApiResponse<EmptyResponse> = try await networkClient.request(endpoint)

        Logger.authLog("✅", "[AuthRepository] FCM token registered successfully")
    }
}
