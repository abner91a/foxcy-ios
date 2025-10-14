//
//  NovelRepositoryImpl.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

final class NovelRepositoryImpl: NovelRepositoryProtocol {
    private let networkClient: NetworkClientProtocol

    init(networkClient: NetworkClientProtocol) {
        self.networkClient = networkClient
    }

    func getTeVaGustar(cursor: String?, limit: Int) async throws -> NovelListResponse {
        let endpoint = NovelEndpoints.teVaGustar(cursor: cursor, limit: limit)
        let response: ApiResponse<HomeDataDTO> = try await networkClient.request(endpoint)

        return NovelListResponse(
            novels: response.data.items.map { $0.toDomain() },
            cursor: response.data.nextCursor,
            hasMore: response.data.hasMore
        )
    }

    func getNovelDetails(id: String, userId: String?) async throws -> NovelDetails {
        let endpoint = NovelEndpoints.novelDetails(id: id, userId: userId)
        let response: ApiResponse<NovelDetailsDTO> = try await networkClient.request(endpoint)
        return response.data.toDomain()
    }

    func getChaptersPaginated(novelId: String, offset: Int, limit: Int) async throws -> ChaptersPaginationResponse {
        let endpoint = NovelEndpoints.chaptersPaginated(novelId: novelId, offset: offset, limit: limit)
        let response: ApiResponse<ChaptersPaginationDTO> = try await networkClient.request(endpoint)
        return response.data.toDomain()
    }

    func searchNovels(query: String, page: Int) async throws -> [Novel] {
        let endpoint = NovelEndpoints.search(query: query, page: page)
        let response: [NovelDTO] = try await networkClient.request(endpoint)
        return response.map { $0.toDomain() }
    }

    func toggleFavorite(novelId: String) async throws {
        let endpoint = NovelEndpoints.toggleFavorite(novelId: novelId)
        try await networkClient.request(endpoint)
    }

    func toggleLike(novelId: String) async throws {
        let endpoint = NovelEndpoints.toggleLike(novelId: novelId)
        try await networkClient.request(endpoint)
    }
}
