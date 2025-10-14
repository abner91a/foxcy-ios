//
//  NovelDTOs.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

// MARK: - Response DTOs
struct HomeDataDTO: Decodable {
    let items: [NovelDTO]
    let nextCursor: String?
    let hasMore: Bool
    let totalCount: Int?
}

struct NovelDTO: Decodable {
    let id: String
    let title: String
    let slug: String
    let description: String
    let coverImage: String
    let status: String
    let views: Int
    let likes: Int
    let rating: Float
    let ratingsCount: Int
    let chaptersCount: Int
    let commentsCount: Int
    let createdAt: String
    let updatedAt: String
    let popularityScore: Float
    let genre: GenreDTO?
    let tags: [TagDTO]?
    let author: String?
}

struct GenreDTO: Decodable {
    let id: String
    let name: String
}

struct TagDTO: Decodable {
    let id: String
    let name: String
    let slug: String?
}

struct NovelDetailsDTO: Decodable {
    let id: String
    let title: String
    let slug: String
    let description: String
    let coverImage: String
    let status: String
    let rating: Float
    let ratingsCount: Int
    let views: Int
    let likes: Int
    let commentsCount: Int
    let chaptersCount: Int
    let author: AuthorDTO
    let genre: GenreDTO
    let tags: [TagDTO]
    let firstChapter: ChapterDTO?
    let lastChapter: ChapterDTO?
    let chapters: [ChapterDTO]
    let createdAt: String
    let updatedAt: String
    let isFavorite: Bool?
    let isLiked: Bool?
}

struct AuthorDTO: Decodable {
    let id: String
    let username: String
    let profileImage: String?
}

struct ChapterDTO: Decodable {
    let id: String
    let title: String
    let order: Int
    let createdAt: String?
    let wordCount: Int?
    let readingTimeMinutes: Int?
    let isRead: Bool?
}

// MARK: - Mappers
extension NovelDTO {
    func toDomain() -> Novel {
        return Novel(
            id: id,
            title: title,
            slug: slug,
            author: author ?? "Autor desconocido",
            description: description,
            coverImageUrl: coverImage,
            status: NovelStatus(rawValue: status.uppercased()) ?? .ongoing,
            rating: rating,
            ratingsCount: ratingsCount,
            views: views,
            likes: likes,
            chaptersCount: chaptersCount,
            commentsCount: commentsCount,
            genres: genre.map { [$0.name] } ?? [],
            tags: tags?.map { $0.name } ?? [],
            popularityScore: popularityScore,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension NovelDetailsDTO {
    func toDomain() -> NovelDetails {
        return NovelDetails(
            id: id,
            title: title,
            slug: slug,
            description: description,
            coverImage: coverImage,
            status: NovelStatus(rawValue: status.uppercased()) ?? .ongoing,
            rating: rating,
            ratingsCount: ratingsCount,
            views: views,
            likes: likes,
            commentsCount: commentsCount,
            chaptersCount: chaptersCount,
            author: author.toDomain(),
            genre: genre.toDomain(),
            tags: tags.map { $0.toDomain() },
            firstChapter: firstChapter?.toDomain(),
            lastChapter: lastChapter?.toDomain(),
            chapters: chapters.map { $0.toDomain() },
            createdAt: createdAt,
            updatedAt: updatedAt,
            isFavorite: isFavorite ?? false,
            isLiked: isLiked ?? false
        )
    }
}

extension AuthorDTO {
    func toDomain() -> AuthorInfo {
        return AuthorInfo(
            id: id,
            username: username,
            profileImage: profileImage
        )
    }
}

extension GenreDTO {
    func toDomain() -> GenreInfo {
        return GenreInfo(id: id, name: name)
    }
}

extension TagDTO {
    func toDomain() -> TagInfo {
        return TagInfo(id: id, name: name, slug: slug ?? "")
    }
}

extension ChapterDTO {
    func toDomain() -> ChapterInfo {
        return ChapterInfo(
            id: id,
            title: title,
            order: order,
            createdAt: createdAt,
            wordCount: wordCount,
            readingTimeMinutes: readingTimeMinutes,
            isRead: isRead ?? false
        )
    }
}

// MARK: - Chapters Pagination DTOs
struct ChaptersPaginationDTO: Decodable {
    let chapters: [ChapterDTO]
    let pagination: PaginationDTO
}

struct PaginationDTO: Decodable {
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
    let sortOrder: String?
}

extension ChaptersPaginationDTO {
    func toDomain() -> ChaptersPaginationResponse {
        return ChaptersPaginationResponse(
            chapters: chapters.map { $0.toDomain() },
            pagination: pagination.toDomain()
        )
    }
}

extension PaginationDTO {
    func toDomain() -> PaginationInfo {
        return PaginationInfo(
            total: total,
            limit: limit,
            offset: offset,
            hasMore: hasMore
        )
    }
}
