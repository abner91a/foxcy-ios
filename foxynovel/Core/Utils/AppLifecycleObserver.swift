//
//  AppLifecycleObserver.swift
//  foxynovel
//
//  Created by Claude on 22/10/25.
//

import Foundation
import UIKit
import OSLog

/// Observador del ciclo de vida de la aplicación para refresh proactivo de tokens
/// Maneja refresh automático cuando la app vuelve a foreground o se lanza
@MainActor
final class AppLifecycleObserver {
    static let shared = AppLifecycleObserver()

    private let tokenManager = TokenManager.shared
    private var authRepository: AuthRepositoryProtocol {
        DIContainer.shared.authRepository
    }

    private init() {
        setupObservers()
        Logger.authLog("🔄", "[AppLifecycle] Observer initialized")
    }

    private func setupObservers() {
        // Observar cuando app vuelve a foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // Observar cuando app termina de lanzarse
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidFinishLaunching),
            name: UIApplication.didFinishLaunchingNotification,
            object: nil
        )
    }

    @objc private func handleAppWillEnterForeground() {
        Logger.authLog("📱", "[AppLifecycle] App entering foreground - checking token")
        Task {
            await checkAndRefreshIfNeeded(trigger: "app_foreground")
        }
    }

    @objc private func handleAppDidFinishLaunching() {
        Logger.authLog("🚀", "[AppLifecycle] App did finish launching - checking token")
        Task {
            await checkAndRefreshIfNeeded(trigger: "app_launch")
        }
    }

    /// Verifica si el token necesita refresh y lo hace si es necesario
    /// - Parameter trigger: Descripción de qué evento disparó el check (para logging)
    private func checkAndRefreshIfNeeded(trigger: String) async {
        // Usar buffer de 10 minutos en lifecycle events (más conservador)
        // porque el usuario podría estar inactivo
        guard tokenManager.shouldRefreshProactively(bufferMinutes: 10) else {
            // Token OK, no necesita refresh
            if let minutes = tokenManager.minutesUntilExpiration() {
                Logger.authLog("✅", "[AppLifecycle] Token valid for \(minutes) more minutes - no refresh needed (\(trigger))")
            }
            return
        }

        Logger.authLog("⏰", "[AppLifecycle] Proactive refresh triggered by: \(trigger)")

        do {
            _ = try await authRepository.refreshAccessToken()
            Logger.authLog("✅", "[AppLifecycle] Proactive refresh successful")

            // Log tiempo restante después del refresh
            if let minutes = tokenManager.minutesUntilExpiration() {
                Logger.debug("[AppLifecycle] New token valid for \(minutes) minutes", category: Logger.auth)
            }
        } catch {
            Logger.error("[AppLifecycle] Proactive refresh failed: \(error)", category: Logger.auth)
            // No problem - reactive refresh will handle it later if needed
            // Don't show error to user, it's a background operation
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
