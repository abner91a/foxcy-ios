//
//  AuthRepository.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

protocol AuthRepositoryProtocol {
    func login(email: String, password: String) async throws -> AuthResponse
    func register(email: String, password: String, username: String) async throws -> AuthResponse
    func logout() async throws
    func getCurrentUser() async throws -> User?
    func isAuthenticated() -> Bool
    func signInWithGoogle() async throws -> AuthResponse
    func refreshAccessToken() async throws -> AuthResponse
    func registerDeviceToken(_ fcmToken: String) async throws
}
