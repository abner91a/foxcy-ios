//
//  AuthDTOs.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

// MARK: - Request DTOs
struct LoginRequestDTO: Encodable {
    let email: String
    let password: String
}

struct RegisterRequestDTO: Encodable {
    let email: String
    let password: String
    let username: String
}

struct GoogleSignInRequestDTO: Encodable {
    let idToken: String
}

struct RefreshTokenRequestDTO: Encodable {
    let refreshToken: String
}

struct RegisterDeviceTokenRequestDTO: Encodable {
    let token: String
    let platform: String
    let tokenType: String
    let appVersion: String?
    let deviceInfo: DeviceInfo?

    struct DeviceInfo: Encodable {
        let model: String?
        let systemVersion: String?
        let deviceId: String?
        let brand: String = "Apple"
        let isDevice: Bool = true
    }
}

// MARK: - Response DTOs
struct AuthResponseDTO: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let user: UserDTO
}

struct UserDTO: Decodable {
    let id: String
    let email: String
    let username: String?
    let profileImage: String?
    let createdAt: String?
}

// MARK: - Mappers
extension AuthResponseDTO {
    func toDomain() -> AuthResponse {
        return AuthResponse(
            token: accessToken,
            refreshToken: refreshToken,
            user: user.toDomain()
        )
    }
}

extension UserDTO {
    func toDomain() -> User {
        return User(
            id: id,
            email: email,
            username: username,
            profileImage: profileImage,
            createdAt: createdAt
        )
    }
}
