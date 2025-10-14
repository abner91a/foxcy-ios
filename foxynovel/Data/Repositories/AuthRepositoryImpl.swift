//
//  AuthRepositoryImpl.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

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
        let response: AuthResponseDTO = try await networkClient.request(endpoint)

        // Save tokens
        tokenManager.saveToken(response.token)
        if let refreshToken = response.refreshToken {
            (tokenManager as? TokenManager)?.saveRefreshToken(refreshToken)
        }

        return response.toDomain()
    }

    func register(email: String, password: String, username: String) async throws -> AuthResponse {
        let endpoint = AuthEndpoints.register(email: email, password: password, username: username)
        let response: AuthResponseDTO = try await networkClient.request(endpoint)

        // Save tokens
        tokenManager.saveToken(response.token)
        if let refreshToken = response.refreshToken {
            (tokenManager as? TokenManager)?.saveRefreshToken(refreshToken)
        }

        return response.toDomain()
    }

    func logout() async throws {
        tokenManager.removeToken()
    }

    func getCurrentUser() async throws -> User? {
        guard isAuthenticated() else { return nil }

        let endpoint = AuthEndpoints.me
        let userDTO: UserDTO = try await networkClient.request(endpoint)
        return userDTO.toDomain()
    }

    func isAuthenticated() -> Bool {
        return (tokenManager as? TokenManager)?.isTokenValid() ?? false
    }
}
