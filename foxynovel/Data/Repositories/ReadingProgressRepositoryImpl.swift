//
//  ReadingProgressRepositoryImpl.swift
//  foxynovel
//
//  Created by Claude on 15/10/25.
//

import SwiftData
import Foundation
import Combine
import OSLog

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

        Logger.databaseLog("✅", "[ReadingProgressRepo] Saved progress for novel: \(progress.novelId)")
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

            Logger.databaseLog("✅", "[ReadingProgressRepo] Updated progress: \(novelId) → chapter \(chapterOrder)")
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
        Logger.syncLog("🗑️", "[ReadingProgressRepo] Deleting progress: \(novelId) (syncWithBackend=\(syncWithBackend))")

        // Paso 1: Eliminar de local inmediatamente (offline-first)
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { $0.novelId == novelId }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try modelContext.save()

            Logger.databaseLog("✅", "[ReadingProgressRepo] Deleted from local: \(novelId)")
        }

        // Paso 2: Eliminar del backend si está autenticado y se solicita sync
        if syncWithBackend && tokenManager.isTokenValid() {
            do {
                let _: ApiResponse<EmptyData> = try await networkClient.request(
                    LibraryEndpoints.deleteProgress(novelId: novelId)
                )

                Logger.syncLog("✅", "[ReadingProgressRepo] Deleted from backend: \(novelId)")
            } catch {
                Logger.error("[ReadingProgressRepo] Backend delete failed (local delete succeeded): \(error)", category: Logger.sync)
                // No lanzar error porque local ya se eliminó
            }
        }
    }

    // MARK: - Sync Operations

    /// Verificar si el usuario puede sincronizar
    func canSync() async -> Bool {
        return tokenManager.isTokenValid()
    }

    // MARK: - Backend Operations

    /// Obtener progreso de una novela desde el backend
    /// Retorna datos enriquecidos con información de novela y autor
    /// 🚀 Usa endpoint GET /api/v1/biblioteca/history/:novelId
    func getNovelProgressFromBackend(novelId: String) async throws -> ReadingProgress? {
        Logger.syncLog("📥", "[ReadingProgressRepo] Fetching progress for novel \(novelId) from backend...")

        // Verificar autenticación
        guard tokenManager.isTokenValid() else {
            Logger.error("[ReadingProgressRepo] Not authenticated", category: Logger.sync)
            throw SyncError.notAuthenticated
        }

        do {
            // Llamar al endpoint enriquecido
            let response: ApiResponse<ReadingProgressEnrichedResponseDto> = try await networkClient.request(
                LibraryEndpoints.getNovelProgress(novelId: novelId)
            )

            let enrichedData = response.data

            Logger.syncLog("✅", "[ReadingProgressRepo] Fetched progress for \(enrichedData.novelTitle ?? "Unknown")")

            // Convertir a dominio
            let domain = enrichedData.toDomain()

            // Convertir a ReadingProgress SwiftData model
            // Necesitamos todos los datos enriquecidos para crear el modelo completo
            guard let novelTitle = enrichedData.novelTitle,
                  let currentChapterId = domain.currentChapterId,
                  !currentChapterId.isEmpty else {
                Logger.debug("[ReadingProgressRepo] Missing required enriched data for novel \(novelId)", category: Logger.sync)
                return nil
            }

            // Crear o actualizar en local
            let context = modelContext
            let existingProgress = await getProgress(novelId: novelId)

            if let existing = existingProgress {
                // Actualizar existente con datos del backend
                existing.currentChapterId = currentChapterId
                existing.currentChapter = domain.currentChapter
                existing.currentPosition = domain.currentPosition
                existing.totalChaptersRead = domain.totalChaptersRead
                existing.lastReadDate = Date(timeIntervalSince1970: TimeInterval(domain.lastReadTime) / 1000)
                existing.totalReadingTime = domain.totalReadingTime
                existing.unsyncedDelta = 0 // Resetear delta después de obtener del backend
                existing.scrollPercentage = domain.scrollPercentage
                existing.segmentIndex = domain.segmentIndex
                existing.updatedAt = Date()

                // Actualizar datos enriquecidos
                existing.novelTitle = novelTitle
                existing.novelCoverImage = enrichedData.novelCoverImage ?? existing.novelCoverImage
                existing.authorName = enrichedData.authorName ?? existing.authorName
                existing.totalChapters = enrichedData.novelChaptersCount ?? existing.totalChapters

                try context.save()
                Logger.syncLog("✅", "[ReadingProgressRepo] Updated local progress from backend")
                return existing
            } else {
                // Crear nuevo registro local
                // Nota: Necesitamos más datos para crear un ReadingProgress completo
                // Este caso debería manejarse con más cuidado en producción
                Logger.debug("[ReadingProgressRepo] Novel \(novelId) not in local DB, consider using fullSync", category: Logger.sync)
                return nil
            }

        } catch {
            Logger.error("[ReadingProgressRepo] Failed to fetch novel progress: \(error)", category: Logger.sync)
            throw SyncError.networkError(error)
        }
    }

    /// Sincronización bidireccional completa (match con Android)
    /// 1. Upload local → backend
    /// 2. Download backend → local (con datos enriquecidos)
    /// 3. Merge con estrategia LWW (Last-Write-Wins) + actualizar datos de novelas
    func fullSync() async throws -> SyncResult {
        syncState = .syncing

        Logger.syncLog("🔄", "[ReadingProgressRepo] Starting full sync...")

        // Verificar autenticación
        guard tokenManager.isTokenValid() else {
            let error = "Por favor inicia sesión para sincronizar"
            Logger.error("[ReadingProgressRepo] \(error)", category: Logger.sync)
            syncState = .error(message: error)
            throw SyncError.notAuthenticated
        }

        do {
            // Paso 1: Upload local history to backend
            let uploadedCount = try await syncToBackend()

            // Paso 2: Download backend history with enriched data (novelTitle, coverImage, authorName)
            let enrichedHistory = try await syncFromBackend()

            // Paso 3: Merge con local usando datos enriquecidos
            let mergedCount = try await mergeWithLocal(enrichedHistory)

            // Actualizar estado
            let syncResult = SyncResult(
                uploadedCount: uploadedCount,
                downloadedCount: enrichedHistory.count,
                mergedCount: mergedCount,
                failedCount: 0
            )

            lastSyncTime = Int64(Date().timeIntervalSince1970 * 1000)
            syncState = .success(synced: mergedCount, failed: 0)

            Logger.syncLog("✅", "[ReadingProgressRepo] Sync completed: \(syncResult)")

            return syncResult

        } catch {
            Logger.error("[ReadingProgressRepo] Sync failed: \(error)", category: Logger.sync)
            syncState = .error(message: error.localizedDescription)
            throw error
        }
    }

    // MARK: - Private Sync Helpers

    /// Sincronizar historial local al backend (Upload)
    /// Envía todo el historial local en una sola request batch
    private func syncToBackend() async throws -> Int {
        Logger.syncLog("📤", "[ReadingProgressRepo] Uploading local history to backend...")

        // Obtener todo el historial local
        let localHistory = await getAllReadingHistory()

        guard !localHistory.isEmpty else {
            Logger.info("[ReadingProgressRepo] No local history to upload", category: Logger.sync)
            return 0
        }

        // Convertir a DTOs
        // 🚀 CRÍTICO: Enviar solo unsyncedDelta (el backend lo sumará al total)
        // 🛡️ ANTI-CHEAT: Validar deltas antes de enviar
        let MAX_SESSION_DELTA_MS: Int64 = 2 * 60 * 60 * 1000 // 2 horas

        let historyDtos = localHistory.compactMap { progress -> ReadingProgressDto? in
            // 🛡️ VALIDACIÓN 1: Delta no debe ser negativo
            guard progress.unsyncedDelta >= 0 else {
                Logger.error("[ReadingProgressRepo] 🚨 FRAUD: Negative delta (\(progress.unsyncedDelta)ms) for novel \(progress.novelId), skipping", category: Logger.sync)
                return nil
            }

            // 🛡️ VALIDACIÓN 2: Skip si delta es 0 (no hay tiempo para sincronizar)
            guard progress.unsyncedDelta > 0 else {
                Logger.debug("[ReadingProgressRepo] Skipping novel \(progress.novelId) - no unsynced time", category: Logger.sync)
                return nil
            }

            // 🛡️ VALIDACIÓN 3: Cap delta a 2 horas si excede
            let validatedDelta: Int64
            if progress.unsyncedDelta > MAX_SESSION_DELTA_MS {
                Logger.info("[ReadingProgressRepo] ⚠️ SUSPICIOUS: Delta too large (\(progress.unsyncedDelta)ms = \(progress.unsyncedDelta/1000/60)min) for novel \(progress.novelId), capping to 2h", category: Logger.sync)
                validatedDelta = MAX_SESSION_DELTA_MS
            } else {
                validatedDelta = progress.unsyncedDelta
            }

            // 🐛 FIX: Convertir currentChapterId vacío a nil (backend espera opcional)
            let chapterId: String? = progress.currentChapterId.isEmpty ? nil : progress.currentChapterId

            // 🐛 FIX: Validar scrollPercentage esté en rango 0-1, o enviar nil
            let validScrollPercentage: Double? = {
                guard let scroll = progress.scrollPercentage else { return nil }
                // Clamp to 0-1 range
                return max(0.0, min(1.0, scroll))
            }()

            return ReadingProgressDto(
                novelId: progress.novelId,
                currentChapter: progress.currentChapter,
                currentPosition: progress.currentPosition,
                totalChaptersRead: progress.totalChaptersRead,
                lastReadTime: progress.lastReadTime,
                totalReadingTime: validatedDelta, // ✅ Delta validado
                currentChapterId: chapterId,
                scrollPercentage: validScrollPercentage,
                segmentIndex: progress.segmentIndex
            )
        }

        // 🛡️ Si todos fueron filtrados, retornar 0
        guard !historyDtos.isEmpty else {
            Logger.info("[ReadingProgressRepo] No valid history to upload after validation", category: Logger.sync)
            return 0
        }

        // Log payload para debugging
        let totalDeltaToSync = localHistory.reduce(0) { $0 + $1.unsyncedDelta }
        Logger.syncLog("📦", "[ReadingProgressRepo] Uploading \(historyDtos.count) items to backend (total unsyncedDelta: \(totalDeltaToSync)ms = \(totalDeltaToSync/1000)s)")

        // Log JSON completo para debugging de errores 400
        if let firstItem = historyDtos.first {
            Logger.debug("[ReadingProgressRepo] Sample item: novelId=\(firstItem.novelId), chapter=\(firstItem.currentChapter), chapterId=\(firstItem.currentChapterId ?? "nil"), scrollPct=\(firstItem.scrollPercentage?.description ?? "nil")", category: Logger.sync)
            Logger.debug("[ReadingProgressRepo] lastReadTime=\(firstItem.lastReadTime), unsyncedDelta=\(firstItem.totalReadingTime)ms, segmentIndex=\(firstItem.segmentIndex)", category: Logger.sync)

            // Serializar a JSON para ver exactamente qué se envía
            if let jsonData = try? JSONEncoder().encode(firstItem),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                Logger.debug("[ReadingProgressRepo] 📋 Sample JSON: \(jsonString)", category: Logger.sync)
            }
        }

        // Enviar al backend
        do {
            let response: ApiResponse<SyncHistoryResponseDto> = try await networkClient.request(
                LibraryEndpoints.syncHistory(body: SyncHistoryDto(history: historyDtos))
            )

            Logger.syncLog("✅", "[ReadingProgressRepo] Upload completed: \(response.data.synced) synced, \(response.data.failed) failed")

            return response.data.synced

        } catch let NetworkError.serverError(statusCode, message) {
            // 🛡️ ANTI-CHEAT: Manejar errores específicos del backend
            switch statusCode {
            case 400:
                Logger.error("[ReadingProgressRepo] 🚨 Backend validation failed (400 Bad Request): \(message ?? "Unknown")", category: Logger.sync)
                Logger.info("[ReadingProgressRepo] Some records were rejected by backend anti-cheat validation", category: Logger.sync)
                throw SyncError.validationFailed("Invalid reading time detected. Please continue reading normally.")

            case 401, 403:
                Logger.error("[ReadingProgressRepo] Authentication error: Session expired", category: Logger.sync)
                throw SyncError.notAuthenticated

            case 429:
                Logger.info("[ReadingProgressRepo] Rate limit exceeded", category: Logger.sync)
                throw SyncError.rateLimitExceeded("Too many sync requests. Please wait a moment.")

            default:
                Logger.error("[ReadingProgressRepo] Upload failed: HTTP \(statusCode)", category: Logger.sync)
                throw SyncError.networkError(NetworkError.serverError(statusCode: statusCode, message: message))
            }

        } catch {
            Logger.error("[ReadingProgressRepo] Upload error: \(error)", category: Logger.sync)
            throw SyncError.networkError(error)
        }
    }

    /// Descargar historial del backend (Download)
    /// Obtiene todo el historial del usuario desde el servidor
    /// 🚀 OPTIMIZACIÓN 2025: También sincroniza datos de novelas desde respuesta enriquecida
    /// Backend retorna ReadingProgressEnrichedResponseDto (alias de ReadingProgressResponseDto)
    private func syncFromBackend() async throws -> [ReadingProgressResponseDto] {
        Logger.syncLog("📥", "[ReadingProgressRepo] Downloading enriched history from backend...")

        // ReadingProgressResponseDto ya incluye datos enriquecidos (novelTitle, novelCoverImage, etc)
        let response: ApiResponse<[ReadingProgressResponseDto]> = try await networkClient.request(
            LibraryEndpoints.getHistory(limit: 1000, offset: 0)
        )

        let enrichedResponses = response.data

        Logger.syncLog("✅", "[ReadingProgressRepo] Downloaded \(enrichedResponses.count) items from backend with enriched data")

        return enrichedResponses
    }

    /// Hacer merge del historial remoto con local
    /// 🚀 Dual Counter Strategy:
    /// - Actualizar totalReadingTime con valor del backend (source of truth)
    /// - Resetear unsyncedDelta a 0 (ya fue acumulado en backend)
    /// 🚀 OPTIMIZACIÓN 2025: Usa datos enriquecidos del backend (novelTitle, coverImage, authorName)
    ///
    /// Para cada novela:
    /// - Si solo existe en remoto → insertar en local con unsyncedDelta=0 + datos enriquecidos
    /// - Si solo existe en local → mantener (ya se subió, esperar download)
    /// - Si existe en ambos → Last-Write-Wins + actualizar total del backend + actualizar datos de novela
    private func mergeWithLocal(_ enrichedHistory: [ReadingProgressResponseDto]) async throws -> Int {
        var mergedCount = 0

        for enrichedDto in enrichedHistory {
            // Convertir a dominio para acceder a campos base
            let remoteDomain = enrichedDto.toDomain()

            // ✅ VALIDAR DATOS CRÍTICOS: Skip entries con datos incompletos para prevenir crashes
            guard let chapterId = remoteDomain.currentChapterId,
                  !chapterId.isEmpty else {
                Logger.debug("[ReadingProgressRepo] Skipping remote entry with missing chapterId: \(remoteDomain.novelId)", category: Logger.sync)
                continue
            }

            let existingProgress = await getProgress(novelId: remoteDomain.novelId)

            if existingProgress == nil {
                // No existe en local → insertar del remoto con datos enriquecidos
                // 🚀 Usar datos reales del backend en lugar de placeholders
                let newProgress = ReadingProgress(
                    novelId: remoteDomain.novelId,
                    novelTitle: enrichedDto.novelTitle ?? "Novela Sin Título",
                    novelCoverImage: enrichedDto.novelCoverImage ?? "",
                    authorName: enrichedDto.authorName ?? "Autor Desconocido",
                    currentChapterId: chapterId, // ✅ Ya validado arriba
                    currentChapter: remoteDomain.currentChapter,
                    currentChapterTitle: "Capítulo \(remoteDomain.currentChapter)",
                    totalChapters: enrichedDto.novelChaptersCount ?? 100
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

                Logger.syncLog("➕", "[ReadingProgressRepo] Inserted new from remote: \(enrichedDto.novelTitle ?? remoteDomain.novelId) (totalTime=\(remoteDomain.totalReadingTime)ms)")

            } else {
                // Existe en ambos → Last-Write-Wins + actualizar total del backend
                if remoteDomain.lastReadTime > existingProgress!.lastReadTime {
                    // Remoto más reciente → actualizar todo
                    existingProgress!.currentChapter = remoteDomain.currentChapter
                    existingProgress!.currentPosition = remoteDomain.currentPosition
                    existingProgress!.currentChapterId = chapterId // ✅ Ya validado arriba
                    existingProgress!.scrollPercentage = remoteDomain.scrollPercentage
                    existingProgress!.segmentIndex = remoteDomain.segmentIndex
                    existingProgress!.totalChaptersRead = remoteDomain.totalChaptersRead
                    existingProgress!.lastReadDate = Date(timeIntervalSince1970: Double(remoteDomain.lastReadTime) / 1000.0)
                }

                // 🚀 ACTUALIZAR datos de novela si vienen en el DTO enriquecido
                if let novelTitle = enrichedDto.novelTitle, !novelTitle.isEmpty {
                    existingProgress!.novelTitle = novelTitle
                }
                if let coverImage = enrichedDto.novelCoverImage, !coverImage.isEmpty {
                    existingProgress!.novelCoverImage = coverImage
                }
                if let authorName = enrichedDto.authorName, !authorName.isEmpty {
                    existingProgress!.authorName = authorName
                }
                if let chaptersCount = enrichedDto.novelChaptersCount, chaptersCount > 0 {
                    existingProgress!.totalChapters = chaptersCount
                }

                // ✅ SIEMPRE actualizar totalReadingTime del backend (source of truth)
                existingProgress!.updateTotalReadingTimeFromBackend(remoteDomain.totalReadingTime)

                // ✅ SIEMPRE resetear delta (ya fue acumulado en backend)
                existingProgress!.resetUnsyncedDelta()

                mergedCount += 1

                Logger.syncLog("🔄", "[ReadingProgressRepo] Updated from remote: \(enrichedDto.novelTitle ?? remoteDomain.novelId) (backend=\(remoteDomain.totalReadingTime)ms, delta reset to 0)")
            }
        }

        try modelContext.save()

        Logger.syncLog("✅", "[ReadingProgressRepo] Merge completed: \(mergedCount) items merged with dual counter strategy and enriched data")

        return mergedCount
    }
}

// MARK: - Helper DTOs

struct EmptyData: Codable {}
