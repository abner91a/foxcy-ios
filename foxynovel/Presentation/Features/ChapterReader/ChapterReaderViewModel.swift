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

    // MARK: - Dependencies
    private let repository: NovelRepositoryProtocol
    private let progressRepository: ReadingProgressRepository

    // MARK: - Private Properties
    private var lastSavedProgress: Double = 0.0
    private var currentNovelId: String = ""
    private var currentNovelTitle: String = ""
    private var currentNovelCoverImage: String = ""
    private var currentAuthorName: String = ""
    private var totalChapters: Int = 0

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

        do {
            let content = try await repository.getChapterContent(chapterId: id)
            chapters.append(content)
            canLoadNext = content.hasNextChapter
            isLoadingChapter = false
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

        do {
            let nextContent = try await repository.getChapterContent(chapterId: nextId)
            chapters.append(nextContent)
            canLoadNext = nextContent.hasNextChapter
            currentChapterId = nextId
            isLoadingChapter = false
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
