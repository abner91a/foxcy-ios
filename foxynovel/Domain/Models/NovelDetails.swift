//
//  NovelDetails.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

struct NovelDetails: Identifiable, Codable {
    let id: String
    let title: String
    let slug: String
    let description: String
    let coverImage: String
    let status: NovelStatus
    let rating: Float
    let ratingsCount: Int
    let views: Int
    let likes: Int
    let commentsCount: Int
    let chaptersCount: Int
    let author: AuthorInfo
    let genre: GenreInfo
    let tags: [TagInfo]
    let firstChapter: ChapterInfo?
    let lastChapter: ChapterInfo?
    let chapters: [ChapterInfo]
    let createdAt: String
    let updatedAt: String

    // User-specific data
    var isFavorite: Bool = false
    var isLiked: Bool = false
}

struct AuthorInfo: Codable, Hashable {
    let id: String
    let username: String
    let profileImage: String?
}

struct GenreInfo: Codable, Hashable {
    let id: String
    let name: String
}

struct TagInfo: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let slug: String
}

struct ChapterInfo: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let order: Int
    let createdAt: String?
    let wordCount: Int?
    let readingTimeMinutes: Int?
    var isRead: Bool = false
}

// MARK: - Chapters Pagination Models
struct ChaptersPaginationResponse {
    let chapters: [ChapterInfo]
    let pagination: PaginationInfo
}

struct PaginationInfo {
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
}
