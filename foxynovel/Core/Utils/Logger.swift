//
//  Logger.swift
//  foxynovel
//
//  Created by Claude on 21/10/25.
//

import Foundation
import OSLog

/// ✅ Sistema centralizado de logging usando OSLog (iOS best practice)
///
/// **Ventajas sobre print():**
/// - Categorización por módulo (Network, Auth, Sync, Database, UI)
/// - Niveles de severidad (debug, info, error, fault)
/// - Filtrado en Console.app
/// - Performance optimizado
/// - Solo aparece en DEBUG automáticamente
/// - Integración con Instruments y Xcode Debugger
///
/// **Uso:**
/// ```swift
/// Logger.debug("Loading data...", category: .network)
/// Logger.info("User logged in", category: .auth)
/// Logger.error("Failed to sync: \(error)", category: .sync)
/// ```
///
/// **Ver logs en Console.app:**
/// 1. Abrir Console.app
/// 2. Filtrar por "subsystem:com.foxynovel.app"
/// 3. Filtrar por category específica (ej: "category:Network")
enum Logger {
    /// Subsystem identifier para la app
    private static let subsystem = "com.foxynovel.app"

    // MARK: - Categorías por Módulo

    /// Logs relacionados con networking (requests, responses, errors)
    static let network = OSLog(subsystem: subsystem, category: "Network")

    /// Logs relacionados con autenticación (login, logout, token refresh)
    static let auth = OSLog(subsystem: subsystem, category: "Auth")

    /// Logs relacionados con sincronización (upload, download, merge)
    static let sync = OSLog(subsystem: subsystem, category: "Sync")

    /// Logs relacionados con base de datos (SwiftData operations)
    static let database = OSLog(subsystem: subsystem, category: "Database")

    /// Logs relacionados con UI (ViewModels, navigation)
    static let ui = OSLog(subsystem: subsystem, category: "UI")

    /// Logs relacionados con cache (capítulos, imágenes)
    static let cache = OSLog(subsystem: subsystem, category: "Cache")

    /// Logs relacionados con configuración y dependencias
    static let config = OSLog(subsystem: subsystem, category: "Config")

    // MARK: - Helper Methods

    /// Log de nivel DEBUG - Para información de desarrollo
    /// Solo visible en DEBUG builds
    static func debug(_ message: String, category: OSLog = .default) {
        #if DEBUG
        os_log(.debug, log: category, "%{public}s", message)
        #endif
    }

    /// Log de nivel INFO - Para eventos importantes normales
    static func info(_ message: String, category: OSLog = .default) {
        os_log(.info, log: category, "%{public}s", message)
    }

    /// Log de nivel ERROR - Para errores recuperables
    static func error(_ message: String, category: OSLog = .default) {
        os_log(.error, log: category, "%{public}s", message)
    }

    /// Log de nivel FAULT - Para errores críticos no recuperables
    static func fault(_ message: String, category: OSLog = .default) {
        os_log(.fault, log: category, "%{public}s", message)
    }

    // MARK: - Helpers con Emoji (Compatibilidad con código existente)

    /// Helper para logs de red con emoji
    static func networkLog(_ emoji: String, _ message: String) {
        debug("\(emoji) \(message)", category: Logger.network)
    }

    /// Helper para logs de auth con emoji
    static func authLog(_ emoji: String, _ message: String) {
        debug("\(emoji) \(message)", category: Logger.auth)
    }

    /// Helper para logs de sync con emoji
    static func syncLog(_ emoji: String, _ message: String) {
        debug("\(emoji) \(message)", category: Logger.sync)
    }

    /// Helper para logs de database con emoji
    static func databaseLog(_ emoji: String, _ message: String) {
        debug("\(emoji) \(message)", category: Logger.database)
    }

    /// Helper para logs de UI con emoji
    static func uiLog(_ emoji: String, _ message: String) {
        debug("\(emoji) \(message)", category: Logger.ui)
    }

    /// Helper para logs de cache con emoji
    static func cacheLog(_ emoji: String, _ message: String) {
        debug("\(emoji) \(message)", category: Logger.cache)
    }

    /// Helper para logs de configuración con emoji
    static func configLog(_ emoji: String, _ message: String) {
        debug("\(emoji) \(message)", category: Logger.config)
    }
}

// MARK: - Migration Guide

/// 📚 GUÍA DE MIGRACIÓN DESDE print():
///
/// **ANTES:**
/// ```swift
/// #if DEBUG
/// print("🔑 [TokenManager] Reading token")
/// #endif
/// ```
///
/// **DESPUÉS:**
/// ```swift
/// Logger.authLog("🔑", "[TokenManager] Reading token")
/// ```
///
/// **O sin emoji:**
/// ```swift
/// Logger.debug("[TokenManager] Reading token", category: .auth)
/// ```
///
/// **Para errores:**
/// ```swift
/// Logger.error("[TokenManager] Failed to decode: \(error)", category: .auth)
/// ```
