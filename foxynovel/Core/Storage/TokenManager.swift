//
//  TokenManager.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation
import Security
import OSLog

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
        Logger.authLog("🔑", "[TokenManager] Reading access token: \(token != nil ? "✅ Found" : "❌ Not found")")
        #if DEBUG
        // 🔒 SEGURIDAD: Solo mostrar preview de token en DEBUG builds
        if let token = token {
            Logger.authLog("🔑", "[TokenManager] Token preview: \(token.prefix(20))...")
        }
        #endif
        return token
    }

    func saveAccessToken(_ token: String) {
        KeychainHelper.save(key: accessTokenKey, value: token)
        #if DEBUG
        // 🔒 SEGURIDAD: Solo mostrar preview de token en DEBUG builds
        Logger.authLog("💾", "[TokenManager] Saved access token: \(token.prefix(20))...")
        #else
        Logger.authLog("💾", "[TokenManager] Access token saved successfully")
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
            Logger.authLog("⚠️", "[TokenManager] No token found, validation failed")
            return false
        }

        // ✅ Usar JWTDecoder centralizado
        let isValid = JWTDecoder.isValid(token)

        Logger.authLog("✅", "[TokenManager] Token validation: \(isValid ? "Valid ✓" : "Expired ✗")")
        return isValid
    }

    // MARK: - Proactive Refresh

    /// Verifica si el token debe refrescarse proactivamente
    /// - Parameter bufferMinutes: Minutos antes de expiración para refrescar (default: 5)
    /// - Returns: true si el token expira en menos de bufferMinutes
    func shouldRefreshProactively(bufferMinutes: TimeInterval = 5) -> Bool {
        guard let token = getAccessToken() else {
            return false // No token, no refresh
        }

        guard let timeLeft = JWTDecoder.timeUntilExpiration(token) else {
            return false // Token inválido, el refresh reactivo lo manejará
        }

        let bufferSeconds = bufferMinutes * 60
        let shouldRefresh = timeLeft < bufferSeconds

        if shouldRefresh {
            Logger.authLog("⏰", "[TokenManager] Token expires in \(Int(timeLeft))s - proactive refresh needed")
        }

        return shouldRefresh
    }

    /// Obtiene tiempo restante hasta expiración en minutos
    /// - Returns: Minutos restantes, o nil si no hay token válido
    func minutesUntilExpiration() -> Int? {
        guard let token = getAccessToken(),
              let timeLeft = JWTDecoder.timeUntilExpiration(token) else {
            return nil
        }
        return Int(timeLeft / 60)
    }
}

// MARK: - Keychain Helper
final class KeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // 🔒 SEGURIDAD MEJORADA: Atributos de protección del Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // ✅ Solo accesible cuando el dispositivo está desbloqueado
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            // ✅ NO sincronizar con iCloud Keychain (mayor seguridad)
            kSecAttrSynchronizable as String: false
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
