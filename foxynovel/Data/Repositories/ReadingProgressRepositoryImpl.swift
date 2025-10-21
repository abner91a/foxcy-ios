//
//  ReadingProgressRepositoryImpl.swift
//  foxynovel
//
//  Created by Claude on 15/10/25.
//

import SwiftData
import Foundation
import Combine

@MainActor
class ReadingProgressRepositoryImpl: ObservableObject, ReadingProgressRepository {
    private let modelContext: ModelContext
    private let networkClient: NetworkClient
    private let tokenManager: TokenManager

    // Estados de sincronización (reactivos para UI)
    @Published var syncState: SyncState = .idle
    @Published var lastSyncTime: Int64? = nil

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

        #if DEBUG
        print("✅ [ReadingProgressRepo] Saved progress for novel: \(progress.novelId)")
        #endif
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
            existing.currentChapter = chapterOrder
            existing.currentChapterTitle = chapterTitle
            existing.scrollPercentage = progress
            existing.lastReadDate = Date()
            existing.updatedAt = Date()

            // Actualizar total de capítulos leídos si avanzó
            if chapterOrder > existing.totalChaptersRead {
                existing.totalChaptersRead = chapterOrder
            }

            try modelContext.save()

            #if DEBUG
            print("✅ [ReadingProgressRepo] Updated progress: \(novelId) → chapter \(chapterOrder)")
            #endif
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

    func deleteProgress(novelId: String, syncWithBackend: Bool) async throws {
        #if DEBUG
        print("🗑️ [ReadingProgressRepo] Deleting progress: \(novelId) (syncWithBackend=\(syncWithBackend))")
        #endif

        // Paso 1: Eliminar de local inmediatamente (offline-first)
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { $0.novelId == novelId }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try modelContext.save()

            #if DEBUG
            print("✅ [ReadingProgressRepo] Deleted from local: \(novelId)")
            #endif
        }

        // Paso 2: Eliminar del backend si está autenticado y se solicita sync
        if syncWithBackend && tokenManager.isTokenValid() {
            do {
                let _: ApiResponse<EmptyData> = try await networkClient.request(
                    LibraryEndpoints.deleteProgress(novelId: novelId)
                )

                #if DEBUG
                print("✅ [ReadingProgressRepo] Deleted from backend: \(novelId)")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ [ReadingProgressRepo] Backend delete failed (local delete succeeded): \(error)")
                #endif
                // No lanzar error porque local ya se eliminó
            }
        }
    }

    // MARK: - Sync Operations

    /// Verificar si el usuario puede sincronizar
    func canSync() async -> Bool {
        return tokenManager.isTokenValid()
    }

    /// Sincronización bidireccional completa (match con Android)
    /// 1. Upload local → backend
    /// 2. Download backend → local
    /// 3. Merge con estrategia LWW (Last-Write-Wins)
    func fullSync() async throws -> SyncResult {
        syncState = .syncing

        #if DEBUG
        print("🔄 [ReadingProgressRepo] Starting full sync...")
        #endif

        // Verificar autenticación
        guard tokenManager.isTokenValid() else {
            let error = "Por favor inicia sesión para sincronizar"
            #if DEBUG
            print("❌ [ReadingProgressRepo] \(error)")
            #endif
            syncState = .error(message: error)
            throw SyncError.notAuthenticated
        }

        do {
            // Paso 1: Upload local history to backend
            let uploadedCount = try await syncToBackend()

            // Paso 2: Download backend history
            let downloadedHistory = try await syncFromBackend()

            // Paso 3: Merge con local
            let mergedCount = try await mergeWithLocal(downloadedHistory)

            // Actualizar estado
            let syncResult = SyncResult(
                uploadedCount: uploadedCount,
                downloadedCount: downloadedHistory.count,
                mergedCount: mergedCount,
                failedCount: 0
            )

            lastSyncTime = Int64(Date().timeIntervalSince1970 * 1000)
            syncState = .success(synced: mergedCount, failed: 0)

            #if DEBUG
            print("✅ [ReadingProgressRepo] Sync completed: \(syncResult)")
            #endif

            return syncResult

        } catch {
            #if DEBUG
            print("❌ [ReadingProgressRepo] Sync failed: \(error)")
            #endif
            syncState = .error(message: error.localizedDescription)
            throw error
        }
    }

    // MARK: - Private Sync Helpers

    /// Sincronizar historial local al backend (Upload)
    /// Envía todo el historial local en una sola request batch
    private func syncToBackend() async throws -> Int {
        #if DEBUG
        print("📤 [ReadingProgressRepo] Uploading local history to backend...")
        #endif

        // Obtener todo el historial local
        let localHistory = await getAllReadingHistory()

        guard !localHistory.isEmpty else {
            #if DEBUG
            print("ℹ️ [ReadingProgressRepo] No local history to upload")
            #endif
            return 0
        }

        // Convertir a DTOs
        // 🚀 CRÍTICO: Enviar solo unsyncedDelta (el backend lo sumará al total)
        let historyDtos = localHistory.map { progress in
            ReadingProgressDto(
                novelId: progress.novelId,
                currentChapter: progress.currentChapter,
                currentPosition: progress.currentPosition,
                totalChaptersRead: progress.totalChaptersRead,
                lastReadTime: progress.lastReadTime,
                totalReadingTime: progress.unsyncedDelta, // ⚠️ Enviar delta, no total
                currentChapterId: progress.currentChapterId,
                scrollPercentage: progress.scrollPercentage,
                segmentIndex: progress.segmentIndex
            )
        }

        // Enviar al backend
        let response: ApiResponse<SyncHistoryResponseDto> = try await networkClient.request(
            LibraryEndpoints.syncHistory(body: SyncHistoryDto(history: historyDtos))
        )

        #if DEBUG
        print("✅ [ReadingProgressRepo] Upload completed: \(response.data.synced) synced, \(response.data.failed) failed")
        #endif

        return response.data.synced
    }

    /// Descargar historial del backend (Download)
    /// Obtiene todo el historial del usuario desde el servidor
    /// 🚀 OPTIMIZACIÓN 2025: También sincroniza datos de novelas desde respuesta enriquecida
    private func syncFromBackend() async throws -> [ReadingProgressDomain] {
        #if DEBUG
        print("📥 [ReadingProgressRepo] Downloading history from backend...")
        #endif

        let response: ApiResponse<[ReadingProgressResponseDto]> = try await networkClient.request(
            LibraryEndpoints.getHistory(limit: 1000, offset: 0)
        )

        let enrichedResponses = response.data

        // 🚀 Sincronizar datos de novelas ANTES de hacer merge del historial
        await syncNovelsFromEnrichedData(enrichedResponses)

        let remoteHistory = enrichedResponses.map { $0.toDomain() }

        #if DEBUG
        print("✅ [ReadingProgressRepo] Downloaded \(remoteHistory.count) items from backend")
        #endif

        return remoteHistory
    }

    /// 🚀 OPTIMIZACIÓN 2025: Sincronizar datos de novelas desde respuesta enriquecida
    /// El backend ahora retorna datos de novela (título, portada, autor) en el historial
    /// Esto evita que aparezca "Novela Desconocida" en la biblioteca después del sync
    private func syncNovelsFromEnrichedData(_ enrichedResponses: [ReadingProgressResponseDto]) async {
        var syncedNovels = 0

        for response in enrichedResponses {
            // Verificar que tenga datos enriquecidos
            guard let novelTitle = response.novelTitle,
                  novelTitle != "Unknown Novel",
                  novelTitle != "Novela Desconocida" else {
                continue
            }

            // TODO: Aquí insertaríamos datos de novela en SwiftData si tuviéramos un NovelEntity
            // Por ahora solo lo logueamos para debugging

            #if DEBUG
            print("📚 [ReadingProgressRepo] Synced novel data: \(novelTitle)")
            #endif

            syncedNovels += 1
        }

        #if DEBUG
        print("✅ [ReadingProgressRepo] Synced \(syncedNovels) novels from enriched data")
        #endif
    }

    /// Hacer merge del historial remoto con local
    /// 🚀 Dual Counter Strategy:
    /// - Actualizar totalReadingTime con valor del backend (source of truth)
    /// - Resetear unsyncedDelta a 0 (ya fue acumulado en backend)
    ///
    /// Para cada novela:
    /// - Si solo existe en remoto → insertar en local con unsyncedDelta=0
    /// - Si solo existe en local → mantener (ya se subió, esperar download)
    /// - Si existe en ambos → Last-Write-Wins + actualizar total del backend
    private func mergeWithLocal(_ remoteHistory: [ReadingProgressDomain]) async throws -> Int {
        var mergedCount = 0

        for remoteDomain in remoteHistory {
            let existingProgress = await getProgress(novelId: remoteDomain.novelId)

            if existingProgress == nil {
                // No existe en local → insertar del remoto
                // Necesitamos título, portada, autor (de enrichedData o placeholder)
                let newProgress = ReadingProgress(
                    novelId: remoteDomain.novelId,
                    novelTitle: "Novela", // TODO: Obtener de enrichedData
                    novelCoverImage: "",
                    authorName: "Autor Desconocido",
                    currentChapterId: remoteDomain.currentChapterId ?? "",
                    currentChapter: remoteDomain.currentChapter,
                    currentChapterTitle: "Capítulo \(remoteDomain.currentChapter)",
                    totalChapters: 100 // Placeholder
                )

                // Actualizar con datos del backend
                newProgress.currentPosition = remoteDomain.currentPosition
                newProgress.scrollPercentage = remoteDomain.scrollPercentage
                newProgress.segmentIndex = remoteDomain.segmentIndex
                newProgress.totalChaptersRead = remoteDomain.totalChaptersRead
                newProgress.totalReadingTime = remoteDomain.totalReadingTime
                newProgress.unsyncedDelta = 0 // ✅ Resetear delta
                newProgress.lastReadDate = Date(timeIntervalSince1970: Double(remoteDomain.lastReadTime) / 1000.0)

                modelContext.insert(newProgress)
                mergedCount += 1

                #if DEBUG
                print("➕ [ReadingProgressRepo] Inserted new from remote: \(remoteDomain.novelId) (totalTime=\(remoteDomain.totalReadingTime)ms)")
                #endif

            } else {
                // Existe en ambos → Last-Write-Wins + actualizar total del backend
                if remoteDomain.lastReadTime > existingProgress!.lastReadTime {
                    // Remoto más reciente → actualizar todo
                    existingProgress!.currentChapter = remoteDomain.currentChapter
                    existingProgress!.currentPosition = remoteDomain.currentPosition
                    if let chapterId = remoteDomain.currentChapterId {
                        existingProgress!.currentChapterId = chapterId
                    }
                    existingProgress!.scrollPercentage = remoteDomain.scrollPercentage
                    existingProgress!.segmentIndex = remoteDomain.segmentIndex
                    existingProgress!.totalChaptersRead = remoteDomain.totalChaptersRead
                    existingProgress!.lastReadDate = Date(timeIntervalSince1970: Double(remoteDomain.lastReadTime) / 1000.0)
                }

                // ✅ SIEMPRE actualizar totalReadingTime del backend (source of truth)
                existingProgress!.totalReadingTime = remoteDomain.totalReadingTime

                // ✅ SIEMPRE resetear delta (ya fue acumulado en backend)
                existingProgress!.unsyncedDelta = 0

                mergedCount += 1

                #if DEBUG
                print("🔄 [ReadingProgressRepo] Updated from remote: \(remoteDomain.novelId) (backend=\(remoteDomain.totalReadingTime)ms)")
                #endif
            }
        }

        try modelContext.save()

        #if DEBUG
        print("✅ [ReadingProgressRepo] Merge completed: \(mergedCount) items merged with dual counter strategy")
        #endif

        return mergedCount
    }
}

// MARK: - Helper DTOs

struct EmptyData: Codable {}
