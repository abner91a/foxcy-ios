//
//  NetworkError.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case encodingError(Error)
    case serverError(statusCode: Int, message: String?)
    case unauthorized
    case networkFailure(Error)
    case maxRetriesExceeded  // ✅ Prevenir recursión infinita en token refresh
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return message ?? "Server error with status code: \(statusCode)"
        case .unauthorized:
            return "Unauthorized. Please login again."
        case .networkFailure(let error):
            return "Network failure: \(error.localizedDescription)"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded. Please try again later."
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
