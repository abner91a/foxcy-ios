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
    @Published private(set) var state: LoadingState<ChapterContent> = .idle
    @Published private(set) var currentChapterId: String = ""

    // MARK: - Dependencies
    private let repository: NovelRepositoryProtocol

    // MARK: - Initialization
    init(repository: NovelRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Public Methods
    func loadChapter(id: String) async {
        currentChapterId = id
        state = .loading

        do {
            let content = try await repository.getChapterContent(chapterId: id)
            state = .success(content)
        } catch {
            state = .failure(error)
        }
    }

    func navigateToPreviousChapter() async {
        guard case .success(let content) = state,
              let previousId = content.previousChapterId else {
            return
        }
        await loadChapter(id: previousId)
    }

    func navigateToNextChapter() async {
        guard case .success(let content) = state,
              let nextId = content.nextChapterId else {
            return
        }
        await loadChapter(id: nextId)
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
