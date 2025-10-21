//
//  NetworkClient.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

protocol NetworkClientProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func request(_ endpoint: Endpoint) async throws
}

final class NetworkClient: NetworkClientProtocol {
    private let session: URLSession
    private let tokenProvider: TokenProvider
    private var isRefreshing: Bool = false
    private var refreshLock = NSLock()

    init(
        session: URLSession = .shared,
        tokenProvider: TokenProvider = TokenManager.shared
    ) {
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
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
                #if DEBUG
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Failed to decode response: \(jsonString)")
                }
                print("Decoding error: \(error)")
                #endif
                throw NetworkError.decodingError(error)
            }
        case 401:
            // Token expired - attempt automatic refresh
            #if DEBUG
            print("🔄 [NetworkClient] 401 Unauthorized - attempting token refresh")
            #endif

            if let refreshed = try? await attemptTokenRefresh() {
                if refreshed {
                    #if DEBUG
                    print("✅ [NetworkClient] Token refreshed, retrying request")
                    #endif
                    // Retry original request with new token
                    return try await request(endpoint)
                }
            }

            #if DEBUG
            print("❌ [NetworkClient] Token refresh failed - user needs to login")
            #endif
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
    private func attemptTokenRefresh() async throws -> Bool {
        // Prevent multiple simultaneous refresh attempts
        refreshLock.lock()
        defer { refreshLock.unlock() }

        if isRefreshing {
            #if DEBUG
            print("⏳ [NetworkClient] Token refresh already in progress")
            #endif
            return false
        }

        isRefreshing = true
        defer { isRefreshing = false }

        // Get refresh token
        guard let tokenManager = tokenProvider as? TokenManager,
              let refreshToken = tokenManager.getRefreshToken() else {
            #if DEBUG
            print("❌ [NetworkClient] No refresh token available")
            #endif
            return false
        }

        do {
            // Create refresh endpoint
            let refreshEndpoint = AuthEndpoints.refreshToken(refreshToken: refreshToken)

            // Make refresh request without going through interceptor
            var urlRequest = try refreshEndpoint.asURLRequest()
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                #if DEBUG
                print("❌ [NetworkClient] Refresh request failed")
                #endif
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

            #if DEBUG
            print("✅ [NetworkClient] Tokens refreshed successfully")
            #endif

            return true
        } catch {
            #if DEBUG
            print("❌ [NetworkClient] Token refresh error: \(error)")
            #endif
            return false
        }
    }

    func request(_ endpoint: Endpoint) async throws {
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
