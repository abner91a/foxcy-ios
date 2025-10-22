//
//  JWTDecoder.swift
//  foxynovel
//
//  Created by Claude on 21/10/25.
//

import Foundation

/// ✅ Utilidad centralizada para decodificar y validar JWT tokens
///
/// **Responsabilidades:**
/// - Decodificar JWT tokens sin dependencias externas
/// - Validar expiración de tokens
/// - Extraer payload con información del usuario
///
/// **Uso:**
/// ```swift
/// if let payload = JWTDecoder.decode(token) {
///     print("User ID: \(payload.id ?? "unknown")")
///     print("Email: \(payload.email ?? "unknown")")
/// }
///
/// if JWTDecoder.isExpired(token) {
///     // Token expiró, refresh needed
/// }
/// ```
enum JWTDecoder {

    // MARK: - Payload Structure

    /// Estructura del payload de un JWT
    struct Payload: Decodable {
        let exp: TimeInterval  // Expiration time (Unix timestamp)
        let iat: TimeInterval? // Issued at (Unix timestamp)
        let id: String?        // User ID
        let email: String?     // User email
        let roles: [String]?   // User roles
    }

    // MARK: - Public Methods

    /// Decodifica un JWT token y retorna el payload
    /// - Parameter token: JWT token string
    /// - Returns: Payload decodificado, o nil si el token es inválido
    static func decode(_ token: String) -> Payload? {
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else {
            return nil
        }

        guard let payloadData = base64UrlDecode(segments[1]),
              let payload = try? JSONDecoder().decode(Payload.self, from: payloadData) else {
            return nil
        }

        return payload
    }

    /// Verifica si un token está expirado
    /// - Parameter token: JWT token string
    /// - Returns: true si el token está expirado o es inválido, false si es válido
    static func isExpired(_ token: String) -> Bool {
        guard let payload = decode(token) else {
            return true // Token inválido = expirado
        }

        return payload.exp <= Date().timeIntervalSince1970
    }

    /// Verifica si un token es válido (no expirado)
    /// - Parameter token: JWT token string
    /// - Returns: true si el token es válido y no expirado
    static func isValid(_ token: String) -> Bool {
        return !isExpired(token)
    }

    /// Obtiene el tiempo restante hasta la expiración
    /// - Parameter token: JWT token string
    /// - Returns: Segundos restantes, o nil si el token es inválido
    static func timeUntilExpiration(_ token: String) -> TimeInterval? {
        guard let payload = decode(token) else {
            return nil
        }

        let remaining = payload.exp - Date().timeIntervalSince1970
        return max(0, remaining) // No retornar valores negativos
    }

    // MARK: - Private Helpers

    /// Decodifica un string en formato Base64 URL-safe
    /// - Parameter value: String codificado en base64 URL-safe
    /// - Returns: Data decodificada, o nil si falla
    private static func base64UrlDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Agregar padding si es necesario
        let length = Double(base64.lengthOfBytes(using: .utf8))
        let requiredLength = 4 * ceil(length / 4.0)
        let paddingLength = requiredLength - length

        if paddingLength > 0 {
            let padding = String(repeating: "=", count: Int(paddingLength))
            base64 += padding
        }

        return Data(base64Encoded: base64)
    }
}

// MARK: - Usage Examples

/// 📚 EJEMPLOS DE USO:
///
/// **1. Decodificar y leer información del usuario:**
/// ```swift
/// if let payload = JWTDecoder.decode(accessToken) {
///     print("User: \(payload.email ?? "unknown")")
///     print("Roles: \(payload.roles ?? [])")
/// }
/// ```
///
/// **2. Validar si token está activo:**
/// ```swift
/// guard JWTDecoder.isValid(accessToken) else {
///     print("Token expired, requesting refresh...")
///     return
/// }
/// ```
///
/// **3. Mostrar tiempo restante:**
/// ```swift
/// if let timeLeft = JWTDecoder.timeUntilExpiration(accessToken) {
///     print("Token expires in \(Int(timeLeft / 60)) minutes")
/// }
/// ```
