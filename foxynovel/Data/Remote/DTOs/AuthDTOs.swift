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

// MARK: - Response DTOs
struct AuthResponseDTO: Decodable {
    let token: String
    let refreshToken: String?
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
            token: token,
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
