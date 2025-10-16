//
//  NetworkClient.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

protocol NetworkClientProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func request(_ endpoint: Endpoint) async throws
}

final class NetworkClient: NetworkClientProtocol {
    private let session: URLSession
    private let tokenProvider: TokenProvider

    init(
        session: URLSession = .shared,
        tokenProvider: TokenProvider = TokenManager.shared
    ) {
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        var urlRequest = try endpoint.asURLRequest()

        // Add authorization header if token exists
        if let token = tokenProvider.getToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                // Backend already returns camelCase keys
                return try decoder.decode(T.self, from: data)
            } catch {
                // Log the raw response for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Failed to decode response: \(jsonString)")
                }
                print("Decoding error: \(error)")
                throw NetworkError.decodingError(error)
            }
        case 401:
            throw NetworkError.unauthorized
        case 400...599:
            let errorMessage = try? JSONDecoder().decode(
                ErrorResponse.self,
                from: data
            )
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorMessage?.message
            )
        default:
            throw NetworkError.unknown
        }
    }

    func request(_ endpoint: Endpoint) async throws {
        var urlRequest = try endpoint.asURLRequest()

        // Add authorization header if token exists
        if let token = tokenProvider.getToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw NetworkError.unauthorized
        case 400...599:
            let errorMessage = try? JSONDecoder().decode(
                ErrorResponse.self,
                from: data
            )
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorMessage?.message
            )
        default:
            throw NetworkError.unknown
        }
    }
}

// MARK: - Error Response Model
struct ErrorResponse: Decodable {
    let message: String?
    let error: String?
}

// MARK: - Token Provider Protocol
protocol TokenProvider {
    func getToken() -> String?
    func saveToken(_ token: String)
    func removeToken()
    func isTokenValid() -> Bool
}
