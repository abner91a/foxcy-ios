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

    // 📖 Obtener progreso de una novela específica con datos enriquecidos
    case getNovelProgress(novelId: String)

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
        case .getNovelProgress(let novelId):
            return "/v1/biblioteca/history/\(novelId)"
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
        case .getHistory, .getNovelProgress:
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

    var body: Encodable? {
        switch self {
        case .syncHistory(let syncBody):
            return syncBody
        case .updateProgress(_, let progressBody):
            return progressBody
        case .getHistory, .getNovelProgress, .deleteProgress:
            return nil
        }
    }

    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }
}
