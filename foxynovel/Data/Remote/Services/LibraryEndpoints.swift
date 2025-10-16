//
//  LibraryEndpoints.swift
//  foxynovel
//
//  Created by Claude on 15/10/25.
//

import Foundation

enum LibraryEndpoints: Endpoint {
    case syncProgress(novelId: String, body: SyncProgressBody)
    case getHistory

    var path: String {
        switch self {
        case .syncProgress(let novelId, _):
            return "/v1/biblioteca/history/\(novelId)"
        case .getHistory:
            return "/v1/biblioteca/history"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .syncProgress:
            return .post
        case .getHistory:
            return .get
        }
    }

    var queryParameters: [String: String]? {
        nil
    }

    var body: Data? {
        switch self {
        case .syncProgress(_, let syncBody):
            return try? JSONEncoder().encode(syncBody)
        case .getHistory:
            return nil
        }
    }

    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }
}

// MARK: - DTOs

struct SyncProgressBody: Codable {
    let chapterId: String
    let progress: Double
    let timestamp: String
}

struct EmptyResponse: Codable {}
