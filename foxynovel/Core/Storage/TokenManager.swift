//
//  TokenManager.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation
import Security

final class TokenManager: TokenProvider {
    static let shared = TokenManager()

    private let accessTokenKey = "com.foxynovel.accessToken"
    private let refreshTokenKey = "com.foxynovel.refreshToken"

    private init() {}

    // MARK: - Token Provider
    func getToken() -> String? {
        return getAccessToken()
    }

    func saveToken(_ token: String) {
        saveAccessToken(token)
    }

    func removeToken() {
        deleteAccessToken()
        deleteRefreshToken()
    }

    // MARK: - Access Token
    func getAccessToken() -> String? {
        let token = KeychainHelper.read(key: accessTokenKey)
        #if DEBUG
        print("🔑 [TokenManager] Reading access token: \(token != nil ? "✅ Found" : "❌ Not found")")
        if let token = token {
            print("🔑 [TokenManager] Token preview: \(token.prefix(20))...")
        }
        #endif
        return token
    }

    func saveAccessToken(_ token: String) {
        KeychainHelper.save(key: accessTokenKey, value: token)
        #if DEBUG
        print("💾 [TokenManager] Saved access token: \(token.prefix(20))...")
        #endif
    }

    func deleteAccessToken() {
        KeychainHelper.delete(key: accessTokenKey)
    }

    // MARK: - Refresh Token
    func getRefreshToken() -> String? {
        return KeychainHelper.read(key: refreshTokenKey)
    }

    func saveRefreshToken(_ token: String) {
        KeychainHelper.save(key: refreshTokenKey, value: token)
    }

    func deleteRefreshToken() {
        KeychainHelper.delete(key: refreshTokenKey)
    }

    // MARK: - Token Validation
    func isTokenValid() -> Bool {
        guard let token = getAccessToken() else {
            #if DEBUG
            print("⚠️ [TokenManager] No token found, validation failed")
            #endif
            return false
        }

        // Decode JWT and check expiration
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1,
              let payloadData = base64UrlDecode(segments[1]),
              let payload = try? JSONDecoder().decode(JWTPayload.self, from: payloadData) else {
            #if DEBUG
            print("⚠️ [TokenManager] Token decode failed")
            #endif
            return false
        }

        let isValid = payload.exp > Date().timeIntervalSince1970
        #if DEBUG
        print("✅ [TokenManager] Token validation: \(isValid ? "Valid ✓" : "Expired ✗")")
        #endif
        return isValid
    }

    private func base64UrlDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let length = Double(base64.lengthOfBytes(using: .utf8))
        let requiredLength = 4 * ceil(length / 4.0)
        let paddingLength = requiredLength - length
        if paddingLength > 0 {
            let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
            base64 += padding
        }

        return Data(base64Encoded: base64)
    }
}

// MARK: - JWT Payload
struct JWTPayload: Decodable {
    let exp: TimeInterval
    let iat: TimeInterval?
    let id: String?
    let email: String?
}

// MARK: - Keychain Helper
final class KeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
