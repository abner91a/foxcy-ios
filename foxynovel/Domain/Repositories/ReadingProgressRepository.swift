//
//  ReadingProgressRepository.swift
//  foxynovel
//
//  Created by Claude on 15/10/25.
//

import Foundation
import Combine

protocol ReadingProgressRepository: ObservableObject {
    // Local operations (siempre disponibles, no requieren conexión)
    func saveProgress(_ progress: ReadingProgress) async throws
    func updateProgress(
        novelId: String,
        chapterId: String,
        chapterOrder: Int,
        chapterTitle: String,
        progress: Double
    ) async throws
    func getProgress(novelId: String) async -> ReadingProgress?
    func getAllReadingHistory() async -> [ReadingProgress]
    func deleteProgress(novelId: String, syncWithBackend: Bool) async throws

    // Sync operations (requieren autenticación) - Match con Android
    func fullSync() async throws -> SyncResult
    func canSync() async -> Bool

    // Estados observables para UI (acceso directo a properties)
    var syncState: SyncState { get }
    var lastSyncTime: Int64? { get }
}

// MARK: - Estados de Sincronización

enum SyncState: Equatable {
    case idle
    case syncing
    case success(synced: Int, failed: Int)
    case error(message: String)
}

// MARK: - Resultado de Sincronización

struct SyncResult {
    let uploadedCount: Int
    let downloadedCount: Int
    let mergedCount: Int
    let failedCount: Int

    var isSuccess: Bool {
        failedCount == 0
    }

    var hasPartialSuccess: Bool {
        mergedCount > 0 && failedCount > 0
    }
}

enum SyncError: Error, LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Debes iniciar sesión para sincronizar tu progreso"
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        }
    }
}
