//
//  UserStorage.swift
//  foxynovel
//
//  Created by Claude on 21/10/25.
//

import Foundation
import OSLog

/// Manages secure local storage for user data (non-sensitive information only)
/// Tokens are stored in Keychain via TokenManager for security
final class UserStorage {
    private static let userKey = "com.foxynovel.cachedUser"
    private static let lastUpdateKey = "com.foxynovel.userLastUpdate"

    private static let defaults = UserDefaults.standard

    // MARK: - User Cache

    /// Save user data to local cache (non-sensitive data only)
    static func saveUser(_ user: User) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(user)
            defaults.set(data, forKey: userKey)
            defaults.set(Date(), forKey: lastUpdateKey)

            Logger.authLog("💾", "[UserStorage] User cached: \(user.email)")
        } catch {
            Logger.error("[UserStorage] Failed to save user: \(error)", category: Logger.auth)
        }
    }

    /// Load user data from local cache
    static func loadUser() -> User? {
        guard let data = defaults.data(forKey: userKey) else {
            Logger.info("[UserStorage] No cached user found", category: Logger.auth)
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let user = try decoder.decode(User.self, from: data)

            Logger.authLog("✅", "[UserStorage] User loaded from cache: \(user.email)")

            return user
        } catch {
            Logger.error("[UserStorage] Failed to load user: \(error)", category: Logger.auth)
            return nil
        }
    }

    /// Clear all cached user data (call on logout)
    static func clearUser() {
        defaults.removeObject(forKey: userKey)
        defaults.removeObject(forKey: lastUpdateKey)

        Logger.authLog("🗑️", "[UserStorage] User cache cleared")
    }

    // MARK: - Cache Freshness

    /// Check if cached user data is stale and needs refresh
    /// - Parameter maxAge: Maximum age in seconds (default: 1 hour)
    /// - Returns: true if data should be refreshed from server
    static func shouldRefreshUserData(maxAge: TimeInterval = 3600) -> Bool {
        guard let lastUpdate = defaults.object(forKey: lastUpdateKey) as? Date else {
            return true // No last update, should refresh
        }

        let age = Date().timeIntervalSince(lastUpdate)
        let shouldRefresh = age > maxAge

        if shouldRefresh {
            Logger.debug("[UserStorage] Cache is stale (age: \(Int(age))s), should refresh", category: Logger.auth)
        }

        return shouldRefresh
    }

    /// Get the last time user data was updated
    static func getLastUpdateDate() -> Date? {
        return defaults.object(forKey: lastUpdateKey) as? Date
    }
}
