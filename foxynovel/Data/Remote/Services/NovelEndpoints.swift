//
//  NovelEndpoints.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

enum NovelEndpoints: Endpoint {
    case teVaGustar(cursor: String?, limit: Int)
    case novelDetails(id: String, userId: String?)
    case chaptersPaginated(novelId: String, offset: Int, limit: Int, sortOrder: String?)
    case chapterContent(chapterId: String)
    case search(query: String, page: Int)
    case toggleFavorite(novelId: String)
    case toggleLike(novelId: String)
    case similarNovels(novelId: String)

    var path: String {
        switch self {
        case .teVaGustar:
            return "/v1/home/tevagustar"
        case .novelDetails(let id, _):
            return "/v1/detallesNovelsapp/\(id)"
        case .chaptersPaginated(let novelId, _, _, _):
            return "/v1/detallesNovelsapp/\(novelId)/capitulos"
        case .chapterContent(let chapterId):
            return "/v1/capitulosNovelapp/\(chapterId)/lectura"
        case .search:
            return "/v1/search"
        case .toggleFavorite:
            return "/v1/userinterationNovelapp/favorite"
        case .toggleLike:
            return "/v1/userinterationNovelapp/like"
        case .similarNovels(let novelId):
            return "/v1/detallesNovelsapp/\(novelId)/similar"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .teVaGustar, .novelDetails, .chaptersPaginated, .chapterContent, .search, .similarNovels:
            return .get
        case .toggleFavorite, .toggleLike:
            return .post
        }
    }

    var queryParameters: [String: String]? {
        switch self {
        case .teVaGustar(let cursor, let limit):
            var params: [String: String] = ["limit": "\(limit)"]
            if let cursor = cursor {
                params["cursor"] = cursor
            }
            return params
        case .novelDetails(_, let userId):
            if let userId = userId {
                return ["userId": userId]
            }
            return nil
        case .chaptersPaginated(_, let offset, let limit, let sortOrder):
            var params = ["offset": "\(offset)", "limit": "\(limit)"]
            if let sortOrder = sortOrder {
                params["sortOrder"] = sortOrder
            }
            return params
        case .chapterContent:
            return nil
        case .search(let query, let page):
            return ["q": query, "page": "\(page)"]
        case .toggleFavorite, .toggleLike, .similarNovels:
            return nil
        }
    }

    var body: Encodable? {
        switch self {
        case .toggleFavorite(let novelId):
            return ["novelId": novelId]
        case .toggleLike(let novelId):
            return ["novelId": novelId]
        default:
            return nil
        }
    }
}
