//
//  NovelDetailsViewModel.swift
//  foxynovel
//
//  Created by Claude on 14/10/25.
//

import Foundation
import Combine
import OSLog

@MainActor
final class NovelDetailsViewModel: ObservableObject {
    @Published var novelDetails: NovelDetails?
    @Published var chapters: [ChapterInfo] = []
    @Published var similarNovels: [SimilarNovel] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMoreChapters: Bool = false
    @Published var isLoadingSimilar: Bool = false
    @Published var errorMessage: String?
    @Published var isFavorite: Bool = false
    @Published var isLiked: Bool = false
    @Published var hasMoreChapters: Bool = true
    @Published var sortOrder: String = "asc"

    private let novelRepository: NovelRepositoryProtocol
    private let tokenManager: TokenProvider
    private var currentOffset: Int = 0
    private let chaptersPerPage: Int = 50
    private var currentNovelId: String?

    init(
        novelRepository: NovelRepositoryProtocol,
        tokenManager: TokenProvider
    ) {
        self.novelRepository = novelRepository
        self.tokenManager = tokenManager
    }

    convenience init() {
        self.init(
            novelRepository: DIContainer.shared.novelRepository,
            tokenManager: TokenManager.shared
        )
    }

    func loadNovelDetails(id: String) async {
        isLoading = true
        errorMessage = nil
        currentNovelId = id

        do {
            // Get userId if authenticated
            let userId = tokenManager.getToken() != nil ? getUserIdFromToken() : nil

            let details = try await novelRepository.getNovelDetails(id: id, userId: userId)
            novelDetails = details

            // Set initial favorite/like states
            isFavorite = details.isFavorite
            isLiked = details.isLiked

            // Determinar si hay capítulos por cargar
            hasMoreChapters = details.chaptersCount > 0

            // Cargar primeros 50 capítulos usando endpoint paginado
            await loadInitialChapters()

            // Cargar novelas similares en paralelo
            await loadSimilarNovels()

        } catch {
            errorMessage = "Error al cargar los detalles: \(error.localizedDescription)"
            Logger.error("[NovelDetails] Error loading novel details: \(error)", category: Logger.ui)
        }

        isLoading = false
    }

    func loadInitialChapters() async {
        guard let novelId = currentNovelId else { return }

        isLoadingMoreChapters = true

        do {
            // Cargar primeros 50 capítulos usando endpoint paginado
            let response = try await novelRepository.getChaptersPaginated(
                novelId: novelId,
                offset: 0,
                limit: chaptersPerPage,
                sortOrder: sortOrder
            )

            chapters = response.chapters
            currentOffset = chaptersPerPage
            hasMoreChapters = response.pagination.hasMore

        } catch {
            Logger.error("[NovelDetails] Error loading initial chapters: \(error)", category: Logger.ui)
            // Si falla, intentar usar los capítulos del details como fallback
            if let details = novelDetails {
                chapters = details.chapters
                hasMoreChapters = details.chaptersCount > chapters.count
            }
        }

        isLoadingMoreChapters = false
    }

    func loadMoreChapters() async {
        guard let novelId = currentNovelId,
              !isLoadingMoreChapters,
              hasMoreChapters else {
            return
        }

        isLoadingMoreChapters = true

        do {
            let response = try await novelRepository.getChaptersPaginated(
                novelId: novelId,
                offset: currentOffset,
                limit: chaptersPerPage,
                sortOrder: sortOrder
            )

            // Agregar nuevos capítulos evitando duplicados
            let newChapters = response.chapters.filter { newChapter in
                !chapters.contains(where: { $0.id == newChapter.id })
            }

            chapters.append(contentsOf: newChapters)
            currentOffset += chaptersPerPage
            hasMoreChapters = response.pagination.hasMore

        } catch {
            Logger.error("[NovelDetails] Error loading more chapters: \(error)", category: Logger.ui)
            // No mostramos error al usuario para no interrumpir UX
        }

        isLoadingMoreChapters = false
    }

    func startReading() -> ChapterInfo? {
        // Return first chapter if available
        return chapters.first
    }

    func toggleSortOrder() async {
        // Toggle between asc and desc
        sortOrder = sortOrder == "asc" ? "desc" : "asc"

        // Reset pagination and reload chapters
        currentOffset = 0
        chapters = []
        hasMoreChapters = true

        await loadInitialChapters()
    }

    func toggleFavorite() async {
        guard let novelId = novelDetails?.id else { return }

        // Optimistic update
        isFavorite.toggle()

        do {
            try await novelRepository.toggleFavorite(novelId: novelId)
        } catch {
            // Revert on error
            isFavorite.toggle()
            errorMessage = "Error al actualizar favorito"
            Logger.error("[NovelDetails] Error toggling favorite: \(error)", category: Logger.ui)
        }
    }

    func toggleLike() async {
        guard let novelId = novelDetails?.id else { return }

        // Optimistic update
        isLiked.toggle()

        do {
            try await novelRepository.toggleLike(novelId: novelId)
        } catch {
            // Revert on error
            isLiked.toggle()
            errorMessage = "Error al actualizar like"
            Logger.error("[NovelDetails] Error toggling like: \(error)", category: Logger.ui)
        }
    }

    func shareNovel() {
        guard let novel = novelDetails else { return }
        // TODO: Implement share functionality
        Logger.debug("[NovelDetails] Sharing novel: \(novel.title)", category: Logger.ui)
    }

    func loadSimilarNovels() async {
        guard let novelId = currentNovelId else { return }

        isLoadingSimilar = true

        do {
            let response = try await novelRepository.getSimilarNovels(novelId: novelId)
            similarNovels = response.novels
            Logger.uiLog("✅", "[NovelDetails] Loaded \(response.novels.count) similar novels")
        } catch {
            Logger.error("[NovelDetails] Error loading similar novels: \(error)", category: Logger.ui)
            // No mostramos error al usuario - las novelas similares son opcionales
        }

        isLoadingSimilar = false
    }

    // MARK: - Private Helpers

    private func getUserIdFromToken() -> String? {
        guard let token = tokenManager.getToken() else { return nil }

        // ✅ Usar JWTDecoder centralizado para decodificar token
        guard let payload = JWTDecoder.decode(token) else {
            return nil
        }

        return payload.id
    }
}
