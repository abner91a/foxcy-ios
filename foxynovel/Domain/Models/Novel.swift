//
//  Novel.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

struct Novel: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let slug: String
    let author: String
    let description: String
    let coverImageUrl: String
    let status: NovelStatus
    let rating: Float
    let ratingsCount: Int
    let views: Int
    let likes: Int
    let chaptersCount: Int
    let commentsCount: Int
    let genres: [String]
    let tags: [String]
    let popularityScore: Float
    let createdAt: String
    let updatedAt: String

    // User-specific data
    var isBookmarked: Bool = false
    var isLiked: Bool = false
}

enum NovelStatus: String, Codable {
    case published = "PUBLISHED"
    case ongoing = "ONGOING"
    case completed = "COMPLETED"
    case hiatus = "HIATUS"
    case dropped = "DROPPED"

    var displayName: String {
        switch self {
        case .published: return "Publicado"
        case .ongoing: return "En curso"
        case .completed: return "Completada"
        case .hiatus: return "En pausa"
        case .dropped: return "Abandonada"
        }
    }
}
