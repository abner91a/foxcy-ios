//
//  NetworkClient.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation
import OSLog

protocol NetworkClientProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func request(_ endpoint: Endpoint) async throws
}

/// Actor para coordinar refresh de tokens de forma thread-safe
private actor TokenRefreshCoordinator {
    private var isRefreshing = false
    private var currentRefreshTask: Task<Bool, Error>?

    func performRefresh(
        refresh: @escaping () async throws -> Bool
    ) async -> Bool {
        // Si ya hay un refresh en progreso, esperar a que termine
        if let existingTask = currentRefreshTask {
            return (try? await existingTask.value) ?? false
        }

        // Crear nueva tarea de refresh
        let task = Task {
            isRefreshing = true
            defer {
                isRefreshing = false
                currentRefreshTask = nil
            }
            return try await refresh()
        }

        currentRefreshTask = task
        return (try? await task.value) ?? false
    }
}

final class NetworkClient: NetworkClientProtocol {
    private let session: URLSession
    private let tokenProvider: TokenProvider
    private let refreshCoordinator = TokenRefreshCoordinator()

    init(
        session: URLSession? = nil,
        tokenProvider: TokenProvider = TokenManager.shared
    ) {
        // ✅ Configurar URLSession con timeouts apropiados
        if let session = session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = AppConfiguration.requestTimeout
            configuration.timeoutIntervalForResource = AppConfiguration.resourceTimeout
            configuration.waitsForConnectivity = true  // Esperar conectividad en vez de fallar inmediatamente

            Logger.networkLog("📡", "[NetworkClient] URLSession configured with timeouts: request=\(AppConfiguration.requestTimeout)s, resource=\(AppConfiguration.resourceTimeout)s")

            self.session = URLSession(configuration: configuration)
        }
        self.tokenProvider = tokenProvider
    }

    // ✅ Protocol conformance - delegates to internal implementation
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        return try await _request(endpoint, retryCount: 0)
    }

    // Internal implementation with retry counter
    private func _request<T: Decodable>(_ endpoint: Endpoint, retryCount: Int) async throws -> T {
        // ✅ Prevenir recursión infinita en token refresh
        guard retryCount < AppConfiguration.maxRetryAttempts else {
            Logger.error("[NetworkClient] Max retry attempts exceeded (\(AppConfiguration.maxRetryAttempts) retries)", category: Logger.network)
            throw NetworkError.maxRetriesExceeded
        }

        // ✅ PROACTIVE REFRESH: Verificar si necesitamos refresh antes del request
        if retryCount == 0, // Solo en primer intento, no en retries
           AppConfiguration.isProactiveRefreshEnabled,
           let tokenManager = self.tokenProvider as? TokenManager,
           tokenManager.shouldRefreshProactively(bufferMinutes: AppConfiguration.proactiveRefreshBufferMinutes) {
            Logger.networkLog("⏰", "[NetworkClient] Proactive token refresh before request")
            _ = try? await attemptTokenRefresh()
        }

        if retryCount > 0 {
            Logger.networkLog("🔄", "[NetworkClient] Retry attempt \(retryCount)/\(AppConfiguration.maxRetryAttempts)")
        }

        var urlRequest = try endpoint.asURLRequest()

        // Add authorization header if token exists
        if let token = tokenProvider.getToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                // Backend already returns camelCase keys
                return try decoder.decode(T.self, from: data)
            } catch {
                // Log the raw response for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    Logger.error("[NetworkClient] Failed to decode response: \(jsonString)", category: Logger.network)
                }
                Logger.error("[NetworkClient] Decoding error: \(error)", category: Logger.network)
                throw NetworkError.decodingError(error)
            }
        case 401:
            // Token expired - attempt automatic refresh
            Logger.networkLog("🔄", "[NetworkClient] 401 Unauthorized - attempting token refresh")

            if let refreshed = try? await attemptTokenRefresh() {
                if refreshed {
                    Logger.networkLog("✅", "[NetworkClient] Token refreshed, retrying request")
                    // Retry original request with new token
                    return try await _request(endpoint, retryCount: retryCount + 1)
                }
            }

            Logger.error("[NetworkClient] Token refresh failed - user needs to login", category: Logger.network)
            throw NetworkError.unauthorized
        case 400...599:
            let errorMessage = try? JSONDecoder().decode(
                ErrorResponse.self,
                from: data
            )
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorMessage?.message
            )
        default:
            throw NetworkError.unknown
        }
    }

    /// Attempts to refresh the access token using the refresh token
    /// - Returns: true if refresh was successful, false otherwise
    /// If refresh fails, automatically logs out the user and posts sessionExpired notification
    private func attemptTokenRefresh() async throws -> Bool {
        return await refreshCoordinator.performRefresh { [weak self] in
            guard let self = self else { return false }

            // Get refresh token
            guard let tokenManager = self.tokenProvider as? TokenManager,
                  let refreshToken = tokenManager.getRefreshToken() else {
                Logger.error("[NetworkClient] No refresh token available - session expired", category: Logger.network)
                await self.handleSessionExpired(reason: "no_refresh_token")
                return false
            }

            do {
                // Create refresh endpoint
                let refreshEndpoint = AuthEndpoints.refreshToken(refreshToken: refreshToken)

                // Make refresh request without going through interceptor
                let urlRequest = try refreshEndpoint.asURLRequest()
                let (data, response) = try await self.session.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    Logger.error("[NetworkClient] Invalid HTTP response during refresh", category: Logger.network)
                    await self.handleSessionExpired(reason: "invalid_response")
                    return false
                }

                // Handle non-200 status codes
                guard httpResponse.statusCode == 200 else {
                    Logger.error("[NetworkClient] Refresh request failed with status: \(httpResponse.statusCode)", category: Logger.network)
                    await self.handleSessionExpired(reason: "refresh_token_invalid")
                    return false
                }

                // Decode refresh response
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode(ApiResponse<AuthResponseDTO>.self, from: data)
                let authResponse = apiResponse.data

                // Save new tokens
                tokenManager.saveAccessToken(authResponse.accessToken)
                if let newRefreshToken = authResponse.refreshToken {
                    tokenManager.saveRefreshToken(newRefreshToken)
                }

                // Update cached user data as well
                UserStorage.saveUser(authResponse.user.toDomain())

                Logger.networkLog("✅", "[NetworkClient] Tokens refreshed successfully")

                return true
            } catch {
                Logger.error("[NetworkClient] Token refresh error: \(error)", category: Logger.network)
                await self.handleSessionExpired(reason: "refresh_error: \(error.localizedDescription)")
                return false
            }
        }
    }

    /// Handles session expiration by logging out user and posting notification
    /// - Parameter reason: The reason for session expiration (for logging/analytics)
    private func handleSessionExpired(reason: String) async {
        Logger.authLog("🚪", "[NetworkClient] Session expired: \(reason) - logging out user")

        // Clear all tokens and user data
        if let tokenManager = self.tokenProvider as? TokenManager {
            tokenManager.removeToken()
        }
        UserStorage.clearUser()

        // Post notification on main thread for UI updates
        await MainActor.run {
            NotificationCenter.default.post(
                name: .sessionExpired,
                object: nil,
                userInfo: ["reason": reason]
            )
            NotificationCenter.default.post(name: .tokenRefreshFailed, object: nil)
        }
    }

    func request(_ endpoint: Endpoint) async throws {
        try await _requestVoid(endpoint, retryCount: 0)
    }

    /// Internal void request implementation with retry logic
    private func _requestVoid(_ endpoint: Endpoint, retryCount: Int) async throws {
        // Prevent infinite recursion
        guard retryCount < AppConfiguration.maxRetryAttempts else {
            Logger.error("[NetworkClient] Max retry attempts exceeded for void request", category: Logger.network)
            throw NetworkError.maxRetriesExceeded
        }

        // ✅ PROACTIVE REFRESH: Verificar si necesitamos refresh antes del request
        if retryCount == 0, // Solo en primer intento, no en retries
           AppConfiguration.isProactiveRefreshEnabled,
           let tokenManager = self.tokenProvider as? TokenManager,
           tokenManager.shouldRefreshProactively(bufferMinutes: AppConfiguration.proactiveRefreshBufferMinutes) {
            Logger.networkLog("⏰", "[NetworkClient] Proactive token refresh before void request")
            _ = try? await attemptTokenRefresh()
        }

        var urlRequest = try endpoint.asURLRequest()

        // Add authorization header if token exists
        if let token = tokenProvider.getToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            // Token expired - attempt automatic refresh
            Logger.networkLog("🔄", "[NetworkClient] 401 on void request - attempting token refresh")

            if let refreshed = try? await attemptTokenRefresh() {
                if refreshed {
                    Logger.networkLog("✅", "[NetworkClient] Token refreshed, retrying void request")
                    // Retry original request with new token
                    return try await _requestVoid(endpoint, retryCount: retryCount + 1)
                }
            }

            Logger.error("[NetworkClient] Token refresh failed on void request", category: Logger.network)
            throw NetworkError.unauthorized
        case 400...599:
            let errorMessage = try? JSONDecoder().decode(
                ErrorResponse.self,
                from: data
            )
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorMessage?.message
            )
        default:
            throw NetworkError.unknown
        }
    }
}

// MARK: - Error Response Model
struct ErrorResponse: Decodable {
    let message: String?
    let error: String?
}

// MARK: - Token Provider Protocol
protocol TokenProvider {
    func getToken() -> String?
    func saveToken(_ token: String)
    func removeToken()
    func isTokenValid() -> Bool
}
