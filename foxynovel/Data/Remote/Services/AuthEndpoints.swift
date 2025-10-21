//
//  AuthEndpoints.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

enum AuthEndpoints: Endpoint {
    case login(email: String, password: String)
    case register(email: String, password: String, username: String)
    case me
    case googleSignInIOS(idToken: String)
    case refreshToken(refreshToken: String)

    var path: String {
        switch self {
        case .login:
            return "/v1/auth/login"
        case .register:
            return "/v1/auth/register"
        case .me:
            return "/v1/auth/me"
        case .googleSignInIOS:
            return "/v1/auth/google/ios"
        case .refreshToken:
            return "/v1/auth/refresh"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login, .register, .googleSignInIOS, .refreshToken:
            return .post
        case .me:
            return .get
        }
    }

    var body: Encodable? {
        switch self {
        case .login(let email, let password):
            return LoginRequestDTO(email: email, password: password)
        case .register(let email, let password, let username):
            return RegisterRequestDTO(email: email, password: password, username: username)
        case .me:
            return nil
        case .googleSignInIOS(let idToken):
            return GoogleSignInRequestDTO(idToken: idToken)
        case .refreshToken(let token):
            return RefreshTokenRequestDTO(refreshToken: token)
        }
    }
}
