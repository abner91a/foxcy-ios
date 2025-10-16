//
//  ReadingProgressRepositoryImpl.swift
//  foxynovel
//
//  Created by Claude on 15/10/25.
//

import SwiftData
import Foundation

@MainActor
class ReadingProgressRepositoryImpl: ReadingProgressRepository {
    private let modelContext: ModelContext
    private let networkClient: NetworkClient
    private let tokenManager: TokenManager

    init(
        modelContext: ModelContext,
        networkClient: NetworkClient,
        tokenManager: TokenManager
    ) {
        self.modelContext = modelContext
        self.networkClient = networkClient
        self.tokenManager = tokenManager
    }

    // MARK: - Local Operations

    func saveProgress(_ progress: ReadingProgress) async throws {
        modelContext.insert(progress)
        try modelContext.save()
    }

    func updateProgress(
        novelId: String,
        chapterId: String,
        chapterOrder: Int,
        chapterTitle: String,
        progress: Double
    ) async throws {
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { $0.novelId == novelId }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            // Actualizar progreso existente
            existing.currentChapterId = chapterId
            existing.currentChapterOrder = chapterOrder
            existing.currentChapterTitle = chapterTitle
            existing.progress = progress
            existing.lastReadDate = Date()
            existing.updatedAt = Date()
            existing.needsSync = true

            // Actualizar total de capítulos leídos si avanzó
            if chapterOrder > existing.totalChaptersRead {
                existing.totalChaptersRead = chapterOrder
            }

            try modelContext.save()
        }
    }

    func getProgress(novelId: String) async -> ReadingProgress? {
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { $0.novelId == novelId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func getAllReadingHistory() async -> [ReadingProgress] {
        let descriptor = FetchDescriptor<ReadingProgress>(
            sortBy: [SortDescriptor(\.lastReadDate, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func deleteProgress(novelId: String) async throws {
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { $0.novelId == novelId }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try modelContext.save()
        }
    }

    // MARK: - Sync Operations

    func syncWithBackend() async throws -> SyncResult {
        // Solo sync si hay token (usuario autenticado)
        guard tokenManager.isTokenValid() else {
            throw SyncError.notAuthenticated
        }

        // Obtener items que necesitan sync
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { $0.needsSync == true }
        )
        let itemsToSync = try modelContext.fetch(descriptor)

        guard !itemsToSync.isEmpty else {
            return SyncResult(itemsSynced: 0, itemsFailed: 0, errors: [])
        }

        var synced = 0
        var failed = 0
        var errors: [Error] = []

        // Sync individual por novela
        for item in itemsToSync {
            do {
                try await syncSingleItem(item)
                item.needsSync = false
                item.lastSyncDate = Date()
                synced += 1
            } catch {
                errors.append(error)
                failed += 1
            }
        }

        try modelContext.save()

        return SyncResult(
            itemsSynced: synced,
            itemsFailed: failed,
            errors: errors
        )
    }

    private func syncSingleItem(_ item: ReadingProgress) async throws {
        let body = SyncProgressBody(
            chapterId: item.currentChapterId,
            progress: item.progress,
            timestamp: ISO8601DateFormatter().string(from: item.updatedAt)
        )

        let _: EmptyResponse = try await networkClient.request(
            LibraryEndpoints.syncProgress(novelId: item.novelId, body: body)
        )
    }

    func downloadHistoryFromBackend() async throws {
        guard tokenManager.isTokenValid() else {
            throw SyncError.notAuthenticated
        }

        struct BackendHistoryItem: Codable {
            let novelId: String
            let novel: BackendNovel?
            let chapterId: String
            let chapter: BackendChapter?
            let progress: Double
            let lastReadDate: String

            struct BackendNovel: Codable {
                let title: String
                let coverImage: String
                let author: BackendAuthor
                let chaptersCount: Int

                struct BackendAuthor: Codable {
                    let username: String
                }
            }

            struct BackendChapter: Codable {
                let title: String
                let order: Int
            }
        }

        // GET /api/v1/biblioteca/history
        let response: [BackendHistoryItem] = try await networkClient.request(
            LibraryEndpoints.getHistory
        )

        // Merge con local (servidor gana si timestamp más reciente)
        for serverItem in response {
            try await mergeWithLocal(serverItem)
        }

        try modelContext.save()
    }

    private func mergeWithLocal(_ serverItem: Any) async throws {
        // TODO: Implementar merge cuando tengamos el formato exacto del backend
        // Por ahora solo guardamos local
    }
}
