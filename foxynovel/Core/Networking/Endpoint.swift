//
//  Endpoint.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

protocol Endpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var queryParameters: [String: String]? { get }
    var body: Encodable? { get }
}

extension Endpoint {
    var baseURL: String {
        return "http://localhost:3001/api"
    }

    var headers: [String: String]? {
        return ["Content-Type": "application/json"]
    }

    var queryParameters: [String: String]? {
        return nil
    }

    var body: Encodable? {
        return nil
    }

    func asURLRequest() throws -> URLRequest {
        guard var urlComponents = URLComponents(string: baseURL + path) else {
            throw NetworkError.invalidURL
        }

        if let queryParameters = queryParameters {
            urlComponents.queryItems = queryParameters.map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }

        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = headers

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }
}
