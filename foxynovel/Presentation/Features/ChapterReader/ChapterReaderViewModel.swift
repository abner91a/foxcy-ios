//
//  ChapterReaderViewModel.swift
//  foxynovel
//
//  Created by Claude on 14/10/25.
//

import Foundation
import Combine

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
            print("📦 Loaded chapter from cache: \(cachedContent.title)")
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
            print("📦 Loaded next chapter from cache: \(cachedContent.title)")
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

        // Prefetching: trigger at 75% progress
        if newProgress >= 0.75 && lastPrefetchProgress < 0.75 {
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

            print("📄 Loaded \(response.chapters.count) chapters. Total: \(allChaptersList.count), HasMore: \(hasMoreChaptersToLoad)")
        } catch {
            print("❌ Error loading chapters list: \(error)")
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
    }

    func saveProgressOnExit() async {
        guard let content = currentChapter else { return }
        await saveProgress(progress: 1.0, chapterCompleted: true)
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
                    currentChapterOrder: content.chapterOrder,
                    currentChapterTitle: content.title,
                    totalChapters: totalChapters
                )
                try await progressRepository.saveProgress(newProgress)
            }
        } catch {
            print("❌ Error guardando progreso: \(error)")
        }
    }

    func navigateToPreviousChapter() async {
        guard let content = currentChapter,
              let previousId = content.previousChapterId else {
            return
        }
        await loadInitialChapter(id: previousId)
    }

    func navigateToNextChapter() async {
        guard let content = currentChapter,
              let nextId = content.nextChapterId else {
            return
        }
        await loadInitialChapter(id: nextId)
    }

    // MARK: - Memory Management

    private func cleanupOldChapters() {
        guard chapters.count > maxChaptersInMemory else { return }

        // Keep only last maxChaptersInMemory chapters
        let chaptersToRemove = chapters.count - maxChaptersInMemory
        chapters.removeFirst(chaptersToRemove)

        print("🧹 Cleaned up \(chaptersToRemove) old chapters. Current count: \(chapters.count)")
    }

    private func triggerPrefetch() async {
        guard let currentChapter = currentChapter,
              let nextId = currentChapter.nextChapterId,
              !cacheManager.contains(id: nextId) else {
            return
        }

        print("🔄 Triggering prefetch for next chapter...")
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
