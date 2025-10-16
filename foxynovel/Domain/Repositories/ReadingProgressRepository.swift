//
//  ReadingProgressRepository.swift
//  foxynovel
//
//  Created by Claude on 15/10/25.
//

import Foundation

protocol ReadingProgressRepository {
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
    func deleteProgress(novelId: String) async throws

    // Sync operations (requieren autenticación)
    func syncWithBackend() async throws -> SyncResult
    func downloadHistoryFromBackend() async throws
}

struct SyncResult {
    let itemsSynced: Int
    let itemsFailed: Int
    let errors: [Error]

    var isSuccess: Bool {
        itemsFailed == 0
    }

    var hasPartialSuccess: Bool {
        itemsSynced > 0 && itemsFailed > 0
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
