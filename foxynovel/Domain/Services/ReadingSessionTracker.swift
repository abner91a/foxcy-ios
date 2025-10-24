//
//  ReadingSessionTracker.swift
//  foxynovel
//
//  Created by Claude on 23/10/25.
//

import Foundation
import SwiftUI
import Combine
import OSLog

/// 📊 Servicio para tracking preciso de tiempo de lectura
/// Mide el tiempo real que el usuario pasa leyendo un capítulo
///
/// **Características**:
/// - ⏱️ Timer con granularidad de 100ms
/// - 💾 Auto-save cada 30 segundos
/// - 🔄 Manejo automático de app lifecycle (background/foreground)
/// - 🛡️ Prevención de duplicación de tiempo
/// - 📱 Persistencia con `@AppStorage` para recuperación de crashes
@MainActor
class ReadingSessionTracker: ObservableObject {
    // MARK: - Published Properties

    /// Tiempo acumulado en la sesión actual (milisegundos)
    @Published private(set) var elapsedTime: Int64 = 0

    /// Estado de la sesión (activa o pausada)
    @Published private(set) var isActive: Bool = false

    // MARK: - Private Properties

    /// Timer de alta frecuencia para tracking preciso
    private var timer: Timer?

    /// Timestamp de cuando se inició la sesión
    private var sessionStartTime: Date?

    /// Timestamp del último tick del timer (para calcular delta)
    private var lastTickTime: Date?

    /// ID de la novela actual (para recuperación)
    private var currentNovelId: String?

    /// Callback para guardar tiempo periódicamente
    private var onTimeSave: ((Int64) -> Void)?

    /// Intervalo de auto-save (30 segundos)
    private let autoSaveInterval: TimeInterval = 30.0

    /// Timestamp del último auto-save
    private var lastSaveTime: Date?

    /// 🛡️ ANTI-CHEAT: Duración máxima de sesión (2 horas = 7200 segundos)
    /// Previene que usuarios dejen la app abierta durante la noche para acumular tiempo
    private let maxSessionDuration: TimeInterval = 2 * 60 * 60 // 2 horas

    /// Keys para UserDefaults
    private let unsavedTimeBackupKey = "unsavedReadingTime"
    private let unsavedNovelIdBackupKey = "unsavedReadingNovelId"

    /// Backup de tiempo no guardado (persiste en crashes)
    private var unsavedTimeBackup: Int64 {
        get { Int64(UserDefaults.standard.integer(forKey: unsavedTimeBackupKey)) }
        set { UserDefaults.standard.set(newValue, forKey: unsavedTimeBackupKey) }
    }

    /// ID de novela del backup (para validación)
    private var unsavedNovelIdBackup: String {
        get { UserDefaults.standard.string(forKey: unsavedNovelIdBackupKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: unsavedNovelIdBackupKey) }
    }

    // MARK: - Lifecycle

    init() {
        Logger.reading("📊", "[ReadingSessionTracker] Initialized")
        setupNotifications()
    }

    deinit {
        // Detener timer de forma síncrona en deinit
        // No podemos acceder a isActive (MainActor), simplemente invalidar timer
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Inicia el tracking de tiempo de lectura
    /// - Parameters:
    ///   - novelId: ID de la novela siendo leída
    ///   - onSave: Callback para guardar tiempo periódicamente
    func startTracking(novelId: String, onSave: @escaping (Int64) -> Void) {
        guard !isActive else {
            Logger.reading("⚠️", "[ReadingSessionTracker] Already tracking, ignoring start")
            return
        }

        self.currentNovelId = novelId
        self.onTimeSave = onSave

        // Recuperar tiempo no guardado si es de la misma novela
        if unsavedNovelIdBackup == novelId && unsavedTimeBackup > 0 {
            Logger.reading("♻️", "[ReadingSessionTracker] Recovered \(unsavedTimeBackup)ms from backup")
            elapsedTime = unsavedTimeBackup
            // Limpiar backup después de recuperar
            unsavedTimeBackup = 0
            unsavedNovelIdBackup = ""
        } else {
            elapsedTime = 0
        }

        isActive = true
        sessionStartTime = Date()
        lastTickTime = Date()
        lastSaveTime = Date()

        // Timer con granularidad de 100ms para tracking preciso
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        Logger.reading("▶️", "[ReadingSessionTracker] Started tracking for novel: \(novelId)")
    }

    /// Detiene el tracking y guarda el tiempo acumulado
    /// - Returns: Tiempo total acumulado en milisegundos
    @discardableResult
    func stopTracking() -> Int64 {
        guard isActive else {
            Logger.reading("⚠️", "[ReadingSessionTracker] Not tracking, ignoring stop")
            return 0
        }

        isActive = false
        timer?.invalidate()
        timer = nil

        // Guardar tiempo final
        let finalTime = elapsedTime
        if finalTime > 0 {
            onTimeSave?(finalTime)
            Logger.reading("⏹️", "[ReadingSessionTracker] Stopped. Total time: \(finalTime)ms (\(finalTime/1000)s)")
        }

        // Limpiar estado
        sessionStartTime = nil
        lastTickTime = nil
        lastSaveTime = nil
        currentNovelId = nil
        elapsedTime = 0

        // Limpiar backup
        unsavedTimeBackup = 0
        unsavedNovelIdBackup = ""

        return finalTime
    }

    /// Pausa el tracking temporalmente (ej: app va a background)
    func pauseTracking() {
        guard isActive else { return }

        timer?.invalidate()
        timer = nil

        // Guardar estado actual en backup
        if let novelId = currentNovelId {
            unsavedTimeBackup = elapsedTime
            unsavedNovelIdBackup = novelId
        }

        Logger.reading("⏸️", "[ReadingSessionTracker] Paused. Elapsed: \(elapsedTime)ms")
    }

    /// Resume el tracking después de pausa
    func resumeTracking() {
        guard isActive else { return }
        guard timer == nil else { return } // Ya hay un timer activo

        lastTickTime = Date()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        Logger.reading("▶️", "[ReadingSessionTracker] Resumed. Current time: \(elapsedTime)ms")
    }

    /// Obtiene el tiempo actual sin detener el tracking
    func getCurrentTime() -> Int64 {
        return elapsedTime
    }

    // MARK: - Private Methods

    private func tick() {
        guard isActive, let lastTick = lastTickTime else { return }

        let now = Date()
        let delta = Int64(now.timeIntervalSince(lastTick) * 1000) // Convertir a ms

        // Validar delta razonable (máximo 1 segundo)
        // Previene saltos grandes si el app se pausa inesperadamente
        guard delta > 0 && delta < 1000 else {
            lastTickTime = now
            return
        }

        // 🛡️ ANTI-CHEAT: Verificar si la sesión excede duración máxima (2 horas)
        if let sessionStart = sessionStartTime {
            let sessionDuration = now.timeIntervalSince(sessionStart)
            if sessionDuration >= maxSessionDuration {
                Logger.reading("🛑", "[ReadingSessionTracker] Max session duration (2h) reached. Pausing tracking.")
                Logger.reading("⚠️", "[ReadingSessionTracker] User must close and reopen chapter to continue tracking")

                // Guardar tiempo acumulado y detener sesión
                saveCurrentTime()
                pauseTracking()
                return
            }
        }

        elapsedTime += delta
        lastTickTime = now

        // Auto-save periódico
        if let lastSave = lastSaveTime {
            let timeSinceLastSave = now.timeIntervalSince(lastSave)
            if timeSinceLastSave >= autoSaveInterval {
                saveCurrentTime()
                lastSaveTime = now
            }
        }

        // Actualizar backup
        if let novelId = currentNovelId {
            unsavedTimeBackup = elapsedTime
            unsavedNovelIdBackup = novelId
        }
    }

    private func saveCurrentTime() {
        guard elapsedTime > 0 else { return }

        Logger.reading("💾", "[ReadingSessionTracker] Auto-save: \(elapsedTime)ms (\(elapsedTime/1000)s)")
        onTimeSave?(elapsedTime)

        // Reset elapsed time después de guardar
        elapsedTime = 0

        // Limpiar backup después de guardar
        unsavedTimeBackup = 0
        unsavedNovelIdBackup = ""
    }

    // MARK: - App Lifecycle Notifications

    private func setupNotifications() {
        // App goes to background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // App returns to foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // App will terminate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        Logger.reading("🌙", "[ReadingSessionTracker] App entering background")
        pauseTracking()
    }

    @objc private func appWillEnterForeground() {
        Logger.reading("☀️", "[ReadingSessionTracker] App returning to foreground")
        resumeTracking()
    }

    @objc private func appWillTerminate() {
        Logger.reading("🛑", "[ReadingSessionTracker] App terminating, saving final time")
        stopTracking()
    }
}
