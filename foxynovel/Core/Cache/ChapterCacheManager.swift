//
//  ChapterCacheManager.swift
//  foxynovel
//
//  Created by Claude on 17/10/25.
//

import Foundation
import OSLog

@MainActor
final class ChapterCacheManager {
    // MARK: - Singleton
    static let shared = ChapterCacheManager()

    // MARK: - Properties
    private let cache = NSCache<NSString, CachedChapter>()
    private var prefetchTasks: [String: Task<Void, Never>] = [:]

    // MARK: - Initialization
    private init() {
        cache.countLimit = 10 // Máximo 10 capítulos en caché
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB límite total
    }

    // MARK: - Public Methods

    /// Get chapter from cache
    func get(id: String) -> ChapterContent? {
        return cache.object(forKey: id as NSString)?.content
    }

    /// Set chapter in cache
    func set(chapter: ChapterContent) {
        let cached = CachedChapter(content: chapter)
        let cost = estimateMemoryCost(for: chapter)
        cache.setObject(cached, forKey: chapter.id as NSString, cost: cost)
    }

    /// Check if chapter is cached
    func contains(id: String) -> Bool {
        return cache.object(forKey: id as NSString) != nil
    }

    /// Prefetch chapter in background
    func prefetch(
        chapterId: String,
        repository: NovelRepositoryProtocol
    ) async {
        // Cancel existing prefetch task for this chapter
        prefetchTasks[chapterId]?.cancel()

        // Don't prefetch if already cached
        guard !contains(id: chapterId) else { return }

        let task = Task {
            do {
                let content = try await repository.getChapterContent(chapterId: chapterId)

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                // Cache the result
                set(chapter: content)

                Logger.cacheLog("✅", "[ChapterCache] Prefetched chapter: \(content.title) (ID: \(chapterId))")
            } catch {
                Logger.error("[ChapterCache] Prefetch failed for chapter \(chapterId): \(error)", category: Logger.cache)
            }

            // Remove task from dictionary
            prefetchTasks.removeValue(forKey: chapterId)
        }

        prefetchTasks[chapterId] = task
    }

    /// Cancel all pending prefetch tasks
    func cancelAllPrefetchTasks() {
        prefetchTasks.values.forEach { $0.cancel() }
        prefetchTasks.removeAll()
    }

    /// Cancel specific prefetch task
    func cancelPrefetch(for chapterId: String) {
        prefetchTasks[chapterId]?.cancel()
        prefetchTasks.removeValue(forKey: chapterId)
    }

    /// Clear entire cache
    func clearAll() {
        cache.removeAllObjects()
        cancelAllPrefetchTasks()
    }

    /// Remove specific chapter from cache
    func remove(id: String) {
        cache.removeObject(forKey: id as NSString)
    }

    // MARK: - Private Methods

    /// Estimate memory cost of a chapter for NSCache
    private func estimateMemoryCost(for chapter: ChapterContent) -> Int {
        // Base cost: metadata
        var cost = 1024 // 1KB for metadata

        // Add cost for content segments
        for segment in chapter.contentSegments {
            // Approximate: 2 bytes per character + overhead
            cost += (segment.content.count * 2) + 100

            // Add cost for spans
            cost += segment.spans.count * 50
        }

        return cost
    }
}

// MARK: - Cached Chapter Wrapper
private class CachedChapter {
    let content: ChapterContent
    let cachedAt: Date

    init(content: ChapterContent) {
        self.content = content
        self.cachedAt = Date()
    }
}
