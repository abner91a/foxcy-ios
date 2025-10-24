//
//  ChapterReaderViewModel.swift
//  foxynovel
//
//  Created by Claude on 14/10/25.
//

import Foundation
import Combine
import OSLog

@MainActor
final class ChapterReaderViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var chapters: [ChapterContent] = []
    @Published private(set) var isLoadingChapter: Bool = false
    @Published private(set) var loadingError: Error? = nil
    @Published private(set) var canLoadNext: Bool = true
    @Published private(set) var currentChapterId: String = ""
    @Published private(set) var readingProgress: Float = 0.0
    @Published private(set) var allChaptersList: [ChapterInfo] = []
    @Published private(set) var isLoadingChaptersList: Bool = false
    @Published private(set) var hasMoreChaptersToLoad: Bool = true
    @Published private(set) var currentChaptersOffset: Int = 0

    // MARK: - Dependencies
    private let repository: NovelRepositoryProtocol
    private let progressRepository: ReadingProgressRepository
    private let cacheManager = ChapterCacheManager.shared

    // 📊 Reading time tracker
    private let sessionTracker = ReadingSessionTracker()

    // MARK: - Private Properties
    private var lastSavedProgress: Double = 0.0
    private var currentNovelId: String = ""
    private var currentNovelTitle: String = ""
    private var currentNovelCoverImage: String = ""
    private var currentAuthorName: String = ""
    private var totalChapters: Int = 0

    // Memory management
    private let maxChaptersInMemory = 5
    private var lastPrefetchProgress: Double = 0.0

    // Pagination
    private let chaptersPageSize = 50

    // MARK: - Initialization
    init(repository: NovelRepositoryProtocol, progressRepository: ReadingProgressRepository? = nil) {
        self.repository = repository
        self.progressRepository = progressRepository ?? DIContainer.shared.readingProgressRepository
    }

    // MARK: - Public Methods
    func loadInitialChapter(id: String) async {
        currentChapterId = id
        chapters = []
        isLoadingChapter = true
        loadingError = nil
        canLoadNext = true
        readingProgress = 0.0
        lastPrefetchProgress = 0.0

        // Try cache first
        if let cachedContent = cacheManager.get(id: id) {
            Logger.cacheLog("📦", "[ChapterReader] Loaded chapter from cache: \(cachedContent.title)")
            chapters.append(cachedContent)
            canLoadNext = cachedContent.hasNextChapter
            isLoadingChapter = false

            // Prefetch next chapter if available
            if let nextId = cachedContent.nextChapterId {
                await cacheManager.prefetch(chapterId: nextId, repository: repository)
            }
            return
        }

        do {
            let content = try await repository.getChapterContent(chapterId: id)
            chapters.append(content)
            canLoadNext = content.hasNextChapter
            isLoadingChapter = false

            // Cache it
            cacheManager.set(chapter: content)

            // Prefetch next chapter if available
            if let nextId = content.nextChapterId {
                await cacheManager.prefetch(chapterId: nextId, repository: repository)
            }
        } catch {
            loadingError = error
            isLoadingChapter = false
        }
    }

    func loadNextChapterAppend() async {
        guard !isLoadingChapter,
              canLoadNext,
              let lastChapter = chapters.last,
              let nextId = lastChapter.nextChapterId else {
            return
        }

        isLoadingChapter = true

        // Try cache first
        if let cachedContent = cacheManager.get(id: nextId) {
            Logger.cacheLog("📦", "[ChapterReader] Loaded next chapter from cache: \(cachedContent.title)")
            chapters.append(cachedContent)
            canLoadNext = cachedContent.hasNextChapter
            currentChapterId = nextId
            isLoadingChapter = false

            // Cleanup old chapters if needed
            cleanupOldChapters()

            // Prefetch next chapter if available
            if let nextNextId = cachedContent.nextChapterId {
                await cacheManager.prefetch(chapterId: nextNextId, repository: repository)
            }
            return
        }

        do {
            let nextContent = try await repository.getChapterContent(chapterId: nextId)
            chapters.append(nextContent)
            canLoadNext = nextContent.hasNextChapter
            currentChapterId = nextId
            isLoadingChapter = false

            // Cache it
            cacheManager.set(chapter: nextContent)

            // Cleanup old chapters if needed
            cleanupOldChapters()

            // Prefetch next chapter if available
            if let nextNextId = nextContent.nextChapterId {
                await cacheManager.prefetch(chapterId: nextNextId, repository: repository)
            }
        } catch {
            loadingError = error
            isLoadingChapter = false
        }
    }

    var currentChapter: ChapterContent? {
        chapters.first(where: { $0.id == currentChapterId }) ?? chapters.first
    }

    func updateReadingProgress(segmentIndex: Int, totalSegments: Int) {
        guard totalSegments > 0 else { return }
        readingProgress = Float(segmentIndex + 1) / Float(totalSegments)

        // Guardar progreso solo si cambió significativamente (>5%) para evitar writes constantes
        let newProgress = Double(segmentIndex + 1) / Double(totalSegments)
        if abs(newProgress - lastSavedProgress) > 0.05 {
            lastSavedProgress = newProgress
            Task {
                await saveProgress(progress: newProgress)
            }
        }

        // Prefetching: trigger at 88% progress (optimizado de 75% para evitar prefetch innecesario)
        // 88% asegura que el usuario está realmente cerca del final
        if newProgress >= 0.88 && lastPrefetchProgress < 0.88 {
            lastPrefetchProgress = newProgress
            Task {
                await triggerPrefetch()
            }
        }
    }

    func loadChaptersList(loadMore: Bool = false) async {
        guard !currentNovelId.isEmpty, !isLoadingChaptersList else { return }
        guard loadMore == false || hasMoreChaptersToLoad else { return }

        isLoadingChaptersList = true

        let offset = loadMore ? currentChaptersOffset : 0
        if !loadMore {
            allChaptersList = []
            currentChaptersOffset = 0
            hasMoreChaptersToLoad = true
        }

        do {
            let response = try await repository.getChaptersPaginated(
                novelId: currentNovelId,
                offset: offset,
                limit: chaptersPageSize,
                sortOrder: "asc"
            )

            if loadMore {
                allChaptersList.append(contentsOf: response.chapters)
            } else {
                allChaptersList = response.chapters
            }

            currentChaptersOffset += response.chapters.count
            hasMoreChaptersToLoad = response.pagination.hasMore
            isLoadingChaptersList = false

            Logger.uiLog("📄", "[ChapterReader] Loaded \(response.chapters.count) chapters. Total: \(allChaptersList.count), HasMore: \(hasMoreChaptersToLoad)")
        } catch {
            Logger.error("[ChapterReader] Error loading chapters list: \(error)", category: Logger.ui)
            isLoadingChaptersList = false
        }
    }

    func jumpToChapter(id: String) async {
        // Check if chapter is already in array
        if chapters.contains(where: { $0.id == id }) {
            currentChapterId = id
            return
        }

        // Load chapter as initial (will clear current array)
        await loadInitialChapter(id: id)
    }

    func setNovelInfo(novelId: String, novelTitle: String, coverImage: String, authorName: String, totalChapters: Int) {
        self.currentNovelId = novelId
        self.currentNovelTitle = novelTitle
        self.currentNovelCoverImage = coverImage
        self.currentAuthorName = authorName
        self.totalChapters = totalChapters

        // 📊 Iniciar tracking de tiempo de lectura
        startReadingSession()
    }

    func saveProgressOnExit() async {
        guard let content = currentChapter else { return }
        await saveProgress(progress: 1.0, chapterCompleted: true)

        // 📊 Detener tracking y guardar tiempo
        await stopReadingSession()
    }

    // MARK: - Reading Session Management

    /// Inicia el tracking de tiempo de lectura
    private func startReadingSession() {
        guard !currentNovelId.isEmpty else {
            Logger.reading("⚠️", "[ChapterReader] Cannot start session without novelId")
            return
        }

        sessionTracker.startTracking(novelId: currentNovelId) { [weak self] accumulatedTime in
            guard let self = self else { return }

            Task { @MainActor in
                await self.saveReadingTime(milliseconds: accumulatedTime)
            }
        }

        Logger.reading("▶️", "[ChapterReader] Started reading session for: \(currentNovelTitle)")
    }

    /// Detiene el tracking y guarda el tiempo final
    private func stopReadingSession() async {
        let finalTime = sessionTracker.stopTracking()

        if finalTime > 0 {
            await saveReadingTime(milliseconds: finalTime)
        }

        Logger.reading("⏹️", "[ChapterReader] Stopped reading session. Final time: \(finalTime)ms")
    }

    /// Guarda el tiempo de lectura acumulado en el progreso local
    /// 🛡️ ANTI-CHEAT: Valida velocidad de lectura antes de guardar
    private func saveReadingTime(milliseconds: Int64) async {
        guard !currentNovelId.isEmpty, milliseconds > 0 else { return }

        // 🛡️ VALIDACIÓN: Verificar velocidad de lectura si el capítulo tiene wordCount
        if let content = currentChapter, content.wordCount > 0 {
            let wordCount = content.wordCount
            let minutes = Double(milliseconds) / 1000.0 / 60.0

            // Solo validar si la sesión duró al menos 5 segundos (0.0833 minutos)
            if minutes >= 0.0833 {
                let wpm = Int(Double(wordCount) / minutes)

                // 🚨 VALIDACIÓN: Rechazar si WPM está fuera de rango razonable
                // Rango: 50-1500 WPM en cliente (backend valida 100-1000)
                if wpm < 50 || wpm > 1500 {
                    Logger.error("[ChapterReader] 🚨 FRAUD: Invalid WPM (\(wpm)) for chapter \(content.id) (\(wordCount) words in \(Int(minutes)) min)", category: Logger.reading)
                    Logger.error("[ChapterReader] Reading time NOT saved due to suspicious reading speed", category: Logger.reading)
                    return // NO guardar progreso - velocidad imposible
                }

                // ⚠️ Log warning si está en el límite (cerca de fraude)
                if wpm < 100 || wpm > 1000 {
                    Logger.info("[ChapterReader] ⚠️ SUSPICIOUS: Borderline WPM (\(wpm)) for chapter \(content.id)", category: Logger.reading)
                }
            }
        }

        do {
            // Obtener progreso existente o crear uno nuevo
            var progress = await progressRepository.getProgress(novelId: currentNovelId)

            if progress == nil {
                // Crear progreso si no existe
                guard let content = currentChapter else { return }

                let newProgress = ReadingProgress(
                    novelId: currentNovelId,
                    novelTitle: currentNovelTitle,
                    novelCoverImage: currentNovelCoverImage,
                    authorName: currentAuthorName,
                    currentChapterId: currentChapterId,
                    currentChapter: content.chapterOrder,
                    currentChapterTitle: content.title,
                    totalChapters: totalChapters
                )
                try await progressRepository.saveProgress(newProgress)
                progress = newProgress
            }

            // Acumular tiempo en unsyncedDelta
            if let progress = progress {
                progress.addReadingTime(milliseconds)
                try await progressRepository.updateProgress(
                    novelId: currentNovelId,
                    chapterId: progress.currentChapterId,
                    chapterOrder: progress.currentChapter,
                    chapterTitle: progress.currentChapterTitle,
                    progress: Double(progress.scrollPercentage ?? 0.0)
                )

                Logger.reading("💾", "[ChapterReader] Saved \(milliseconds)ms to unsyncedDelta. Total delta: \(progress.unsyncedDelta)ms")
            }
        } catch {
            Logger.error("[ChapterReader] Error saving reading time: \(error)", category: Logger.reading)
        }
    }

    // MARK: - Private Methods

    private func saveProgress(progress: Double, chapterCompleted: Bool = false) async {
        guard !currentNovelId.isEmpty,
              let content = currentChapter else {
            return
        }

        do {
            // Verificar si ya existe progreso para esta novela
            let existing = await progressRepository.getProgress(novelId: currentNovelId)

            if let existing = existing {
                // Actualizar progreso existente
                try await progressRepository.updateProgress(
                    novelId: currentNovelId,
                    chapterId: currentChapterId,
                    chapterOrder: content.chapterOrder,
                    chapterTitle: content.title,
                    progress: progress
                )
            } else {
                // Crear nuevo progreso
                let newProgress = ReadingProgress(
                    novelId: currentNovelId,
                    novelTitle: currentNovelTitle,
                    novelCoverImage: currentNovelCoverImage,
                    authorName: currentAuthorName,
                    currentChapterId: currentChapterId,
                    currentChapter: content.chapterOrder,
                    currentChapterTitle: content.title,
                    totalChapters: totalChapters
                )
                try await progressRepository.saveProgress(newProgress)
            }
        } catch {
            Logger.error("[ChapterReader] Error guardando progreso: \(error)", category: Logger.sync)
        }
    }

    func navigateToPreviousChapter() async {
        guard let content = currentChapter,
              let previousId = content.previousChapterId else {
            return
        }

        // Guardar progreso actual antes de navegar
        await saveProgress(progress: Double(readingProgress))

        // Si el capítulo ya está cargado, solo actualizar currentChapterId
        if chapters.contains(where: { $0.id == previousId }) {
            currentChapterId = previousId
            readingProgress = 0.0
            lastPrefetchProgress = 0.0
            return
        }

        await loadInitialChapter(id: previousId)
    }

    func navigateToNextChapter() async {
        guard let content = currentChapter,
              let nextId = content.nextChapterId else {
            return
        }

        // Guardar progreso actual antes de navegar
        await saveProgress(progress: Double(readingProgress))

        // Si el capítulo ya está cargado, solo actualizar currentChapterId
        if chapters.contains(where: { $0.id == nextId }) {
            currentChapterId = nextId
            readingProgress = 0.0
            lastPrefetchProgress = 0.0
            return
        }

        await loadInitialChapter(id: nextId)
    }

    // MARK: - Memory Management

    private func cleanupOldChapters() {
        // Optimización: limpiar más agresivamente cuando hay más de 3 capítulos
        // Esto evita acumulación de memoria en sesiones largas de lectura
        guard chapters.count > 3 else { return }

        // Mantener solo los últimos 3 capítulos en memoria
        let chaptersToRemove = chapters.count - 3
        chapters.removeFirst(chaptersToRemove)

        Logger.debug("[ChapterReader] Cleaned up \(chaptersToRemove) old chapters. Current count: \(chapters.count)", category: Logger.cache)
    }

    private func triggerPrefetch() async {
        guard let currentChapter = currentChapter,
              let nextId = currentChapter.nextChapterId,
              !cacheManager.contains(id: nextId) else {
            return
        }

        Logger.cacheLog("🔄", "[ChapterReader] Triggering prefetch for next chapter...")
        await cacheManager.prefetch(chapterId: nextId, repository: repository)
    }
}

// MARK: - Loading State
enum LoadingState<T> {
    case idle
    case loading
    case success(T)
    case failure(Error)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var value: T? {
        if case .success(let value) = self { return value }
        return nil
    }

    var error: Error? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
