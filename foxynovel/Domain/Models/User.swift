//
//  User.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

struct User: Identifiable, Codable {
    let id: String
    let email: String
    let username: String?
    let profileImage: String?
    let createdAt: String?
}

struct AuthResponse: Codable {
    let token: String
    let refreshToken: String?
    let user: User
}
