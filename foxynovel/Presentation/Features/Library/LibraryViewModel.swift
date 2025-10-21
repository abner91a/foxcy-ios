//
//  LibraryViewModel.swift
//  foxynovel
//
//  Created by Claude on 15/10/25.
//

import Foundation
import Combine

@MainActor
class LibraryViewModel: ObservableObject {
    @Published var readingHistory: [ReadingProgress] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let progressRepository: any ReadingProgressRepository
    private let authRepository: AuthRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    // Track para auto-sync
    private var wasAuthenticated = false

    var isAuthenticated: Bool {
        authRepository.isAuthenticated()
    }

    var syncState: SyncState {
        progressRepository.syncState
    }

    var lastSyncTime: Int64? {
        progressRepository.lastSyncTime
    }

    var isSyncing: Bool {
        if case .syncing = syncState {
            return true
        }
        return false
    }

    var syncStatusMessage: String {
        switch syncState {
        case .idle:
            return ""
        case .syncing:
            return "Sincronizando..."
        case .success(let synced, let failed):
            if failed > 0 {
                return "⚠️ \(synced) sincronizadas, \(failed) errores"
            } else if synced > 0 {
                return "✓ \(synced) novelas sincronizadas"
            } else {
                return "✓ Todo sincronizado"
            }
        case .error(let message):
            return "❌ \(message)"
        }
    }

    init(progressRepository: any ReadingProgressRepository, authRepository: AuthRepositoryProtocol) {
        self.progressRepository = progressRepository
        self.authRepository = authRepository

        // 🚀 Auto-sync cuando el usuario hace login (match con Android)
        // Detecta cambios en el estado de autenticación (false → true)
        setupAuthenticationObserver()
    }

    /// Configurar observación de autenticación para auto-sync
    private func setupAuthenticationObserver() {
        // Verificar periódicamente el estado de autenticación
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                let isCurrentlyAuth = self.isAuthenticated

                // Detectar transición de no autenticado → autenticado
                if isCurrentlyAuth && !self.wasAuthenticated {
                    #if DEBUG
                    print("🔑 [LibraryViewModel] User logged in, triggering auto-sync...")
                    #endif

                    // Pequeño delay para asegurar que el token esté listo
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 segundos
                        await self.syncHistory()
                    }
                }

                self.wasAuthenticated = isCurrentlyAuth
            }
            .store(in: &cancellables)
    }

    func loadLibrary() async {
        isLoading = true
        errorMessage = nil

        // Cargar historial local (siempre disponible)
        readingHistory = await progressRepository.getAllReadingHistory()

        isLoading = false
    }

    /// 🔄 Sincronizar historial de lectura con backend
    /// Operación bidireccional: upload local + download remoto + merge
    func syncHistory() async {
        guard isAuthenticated else {
            errorMessage = "Inicia sesión para sincronizar tu progreso"
            return
        }

        do {
            let result = try await progressRepository.fullSync()

            // Recargar historial después de sync exitoso
            await loadLibrary()

            #if DEBUG
            print("✅ [LibraryViewModel] Sync completed: \(result)")
            #endif

        } catch {
            errorMessage = "Error al sincronizar: \(error.localizedDescription)"

            #if DEBUG
            print("❌ [LibraryViewModel] Sync failed: \(error)")
            #endif
        }
    }

    func deleteNovel(_ novelId: String, syncWithBackend: Bool = true) async {
        do {
            try await progressRepository.deleteProgress(novelId: novelId, syncWithBackend: syncWithBackend)
            await loadLibrary()

            #if DEBUG
            print("✅ [LibraryViewModel] Deleted novel: \(novelId)")
            #endif
        } catch {
            errorMessage = "Error al eliminar: \(error.localizedDescription)"

            #if DEBUG
            print("❌ [LibraryViewModel] Delete failed: \(error)")
            #endif
        }
    }

    /// Formatear timestamp de última sincronización para mostrar en UI
    func formattedLastSyncTime() -> String {
        guard let timestamp = lastSyncTime else {
            return "Nunca"
        }

        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Hace un momento"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "Hace \(minutes) min"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "Hace \(hours)h"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}
