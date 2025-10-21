//
//  LibraryEndpoints.swift
//  foxynovel
//
//  Created by Claude on 15/10/25.
//

import Foundation

enum LibraryEndpoints: Endpoint {
    // 🚀 Sincronización masiva (batch upload)
    case syncHistory(body: SyncHistoryDto)

    // 📥 Descargar historial completo con datos enriquecidos
    case getHistory(limit: Int, offset: Int)

    // 📤 Actualizar progreso individual de una novela
    case updateProgress(novelId: String, body: ReadingProgressDto)

    // 🗑️ Eliminar progreso de una novela
    case deleteProgress(novelId: String)

    var path: String {
        switch self {
        case .syncHistory:
            return "/v1/biblioteca/sync"
        case .getHistory:
            return "/v1/biblioteca/history"
        case .updateProgress(let novelId, _):
            return "/v1/biblioteca/history/\(novelId)"
        case .deleteProgress(let novelId):
            return "/v1/biblioteca/history/\(novelId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .syncHistory:
            return .post
        case .getHistory:
            return .get
        case .updateProgress:
            return .put
        case .deleteProgress:
            return .delete
        }
    }

    var queryParameters: [String: String]? {
        switch self {
        case .getHistory(let limit, let offset):
            return [
                "limit": "\(limit)",
                "offset": "\(offset)"
            ]
        default:
            return nil
        }
    }

    var body: Data? {
        switch self {
        case .syncHistory(let syncBody):
            return try? JSONEncoder().encode(syncBody)
        case .updateProgress(_, let progressBody):
            return try? JSONEncoder().encode(progressBody)
        case .getHistory, .deleteProgress:
            return nil
        }
    }

    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }
}
