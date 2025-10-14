//
//  NovelRepository.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

protocol NovelRepositoryProtocol {
    func getTeVaGustar(cursor: String?, limit: Int) async throws -> NovelListResponse
    func getNovelDetails(id: String, userId: String?) async throws -> NovelDetails
    func getChaptersPaginated(novelId: String, offset: Int, limit: Int) async throws -> ChaptersPaginationResponse
    func searchNovels(query: String, page: Int) async throws -> [Novel]
    func toggleFavorite(novelId: String) async throws
    func toggleLike(novelId: String) async throws
}

struct NovelListResponse: Codable {
    let novels: [Novel]
    let cursor: String?
    let hasMore: Bool
}
