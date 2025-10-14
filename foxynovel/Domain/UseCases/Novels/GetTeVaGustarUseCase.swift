//
//  GetTeVaGustarUseCase.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

protocol GetTeVaGustarUseCaseProtocol {
    func execute(cursor: String?, limit: Int) async throws -> NovelListResponse
}

final class GetTeVaGustarUseCase: GetTeVaGustarUseCaseProtocol {
    private let repository: NovelRepositoryProtocol

    init(repository: NovelRepositoryProtocol) {
        self.repository = repository
    }

    func execute(cursor: String? = nil, limit: Int = 20) async throws -> NovelListResponse {
        return try await repository.getTeVaGustar(cursor: cursor, limit: limit)
    }
}
