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
    @Published var isSyncing = false
    @Published var syncStatus: String = ""
    @Published var errorMessage: String?

    private let progressRepository: ReadingProgressRepository
    private let tokenManager: TokenProvider

    var isAuthenticated: Bool {
        tokenManager.isTokenValid()
    }

    var needsSyncCount: Int {
        readingHistory.filter { $0.needsSync }.count
    }

    init(progressRepository: ReadingProgressRepository, tokenManager: TokenProvider) {
        self.progressRepository = progressRepository
        self.tokenManager = tokenManager
    }

    func loadLibrary() async {
        isLoading = true
        errorMessage = nil

        // Cargar historial local
        readingHistory = await progressRepository.getAllReadingHistory()

        // Si está autenticado y hay items pendientes, sync automático
        if isAuthenticated && needsSyncCount > 0 {
            await syncWithBackend()
        }

        isLoading = false
    }

    func syncWithBackend() async {
        guard isAuthenticated else {
            errorMessage = "Inicia sesión para sincronizar tu progreso"
            return
        }

        isSyncing = true
        syncStatus = "Sincronizando..."

        do {
            let result = try await progressRepository.syncWithBackend()

            if result.itemsSynced > 0 {
                syncStatus = "✓ \(result.itemsSynced) novelas sincronizadas"
            }

            if result.itemsFailed > 0 {
                syncStatus = "⚠️ \(result.itemsFailed) errores"
            }

            // Recargar después de sync
            await loadLibrary()

            // Limpiar mensaje después de 3 segundos
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            syncStatus = ""

        } catch {
            errorMessage = "Error al sincronizar: \(error.localizedDescription)"
        }

        isSyncing = false
    }

    func deleteNovel(_ novelId: String) async {
        do {
            try await progressRepository.deleteProgress(novelId: novelId)
            await loadLibrary()
        } catch {
            errorMessage = "Error al eliminar: \(error.localizedDescription)"
        }
    }
}
