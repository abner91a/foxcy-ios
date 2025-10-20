//
//  SimilarNovel.swift
//  foxynovel
//
//  Created by Claude on 20/10/25.
//

import Foundation

/// Modelo ligero para novelas similares
/// Usado en carouseles de recomendaciones
struct SimilarNovel: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let coverImage: String
    let rating: Float
    let chaptersCount: Int
    let similarityScore: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case coverImage
        case rating
        case chaptersCount
        case similarityScore
    }
}

struct SimilarNovelsResponse: Codable {
    let novels: [SimilarNovel]
    let total: Int
    let type: String
}
