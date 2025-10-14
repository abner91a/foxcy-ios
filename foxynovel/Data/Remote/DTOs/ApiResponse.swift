//
//  ApiResponse.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

/// Generic wrapper for all API responses
struct ApiResponse<T: Decodable>: Decodable {
    let ok: Bool
    let message: String?
    let data: T
}
