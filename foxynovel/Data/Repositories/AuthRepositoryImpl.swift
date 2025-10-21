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
        }

        let authResponse = response.toDomain()

        // Cache user data locally for fast access
        UserStorage.saveUser(authResponse.user)

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
        }

        let authResponse = response.toDomain()

        // Cache user data locally for fast access
        UserStorage.saveUser(authResponse.user)

        return authResponse
    }

    func logout() async throws {
        tokenManager.removeToken()
        // Clear cached user data on logout
        UserStorage.clearUser()
    }

    func getCurrentUser() async throws -> User? {
        guard isAuthenticated() else { return nil }

        // Always load from cache - no server calls needed
        // User data is cached after login/register/signIn
        let cachedUser = UserStorage.loadUser()

        #if DEBUG
        if let user = cachedUser {
            print("✅ [AuthRepository] User loaded from cache: \(user.email)")
        } else {
            print("⚠️ [AuthRepository] No cached user found - user needs to login")
        }
        #endif

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

        #if DEBUG
        print("✅ Google Sign-In successful, got ID token")
        #endif

        // 4. Send to backend
        let endpoint = AuthEndpoints.googleSignInIOS(idToken: idToken)
        let apiResponse: ApiResponse<AuthResponseDTO> = try await networkClient.request(endpoint)
        let response = apiResponse.data

        // 5. Save tokens
        tokenManager.saveToken(response.accessToken)
        if let refreshToken = response.refreshToken {
            (tokenManager as? TokenManager)?.saveRefreshToken(refreshToken)
        }

        #if DEBUG
        print("✅ Backend authentication successful")
        #endif

        let authResponse = response.toDomain()

        // Cache user data locally for fast access
        UserStorage.saveUser(authResponse.user)

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

        #if DEBUG
        print("✅ FCM token registered successfully")
        #endif
    }
}
