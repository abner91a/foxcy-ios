//
//  AppConfiguration.swift
//  foxynovel
//
//  Created by Claude on 21/10/25.
//

import Foundation
import OSLog

/// ✅ Centralized configuration management
/// Supports different environments and feature flags
enum AppConfiguration {
    // MARK: - Environment

    enum Environment {
        case development
        case staging
        case production

        static var current: Environment {
            #if DEBUG
            return .development
            #else
            return .production
            #endif
        }
    }

    // MARK: - API Configuration

    static var baseURL: String {
        switch Environment.current {
        case .development:
            // TODO: Reemplazar con la IP real del backend de desarrollo
            // Para encontrar tu IP local: ifconfig | grep "inet " | grep -v 127.0.0.1
            return "http://localhost:3001/api"
        case .staging:
            return "https://staging-api.foxynovel.com/api"
        case .production:
            return "https://api.foxynovel.com/api"
        }
    }

    // MARK: - Feature Flags

    static var isLoggingEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static var isSyncEnabled: Bool {
        return true  // Can be toggled based on remote config
    }

    // MARK: - Network Configuration

    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
    static let maxRetryAttempts: Int = 3

    // MARK: - Token Refresh Configuration

    /// Minutos antes de expiración para hacer refresh proactivo
    /// Balance perfecto entre UX y carga del servidor
    static let proactiveRefreshBufferMinutes: TimeInterval = 5

    /// Habilitar/deshabilitar refresh proactivo de tokens
    /// Refresca automáticamente tokens antes de que expiren
    static var isProactiveRefreshEnabled: Bool {
        return true  // Habilitado en DEBUG y producción
    }

    // MARK: - Debugging

    static func printConfiguration() {
        Logger.configLog("📱", "[AppConfiguration]")
        Logger.debug("   Environment: \(Environment.current)", category: Logger.config)
        Logger.debug("   Base URL: \(baseURL)", category: Logger.config)
        Logger.debug("   Logging: \(isLoggingEnabled)", category: Logger.config)
        Logger.debug("   Sync: \(isSyncEnabled)", category: Logger.config)
        Logger.debug("   Request Timeout: \(requestTimeout)s", category: Logger.config)
        Logger.debug("   Resource Timeout: \(resourceTimeout)s", category: Logger.config)
        Logger.debug("   Max Retries: \(maxRetryAttempts)", category: Logger.config)
    }
}
