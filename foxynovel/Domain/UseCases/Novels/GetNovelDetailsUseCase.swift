//
//  GetNovelDetailsUseCase.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

protocol GetNovelDetailsUseCaseProtocol {
    func execute(novelId: String) async throws -> NovelDetails
}

final class GetNovelDetailsUseCase: GetNovelDetailsUseCaseProtocol {
    private let repository: NovelRepositoryProtocol
    private let authRepository: AuthRepositoryProtocol

    init(
        repository: NovelRepositoryProtocol,
        authRepository: AuthRepositoryProtocol
    ) {
        self.repository = repository
        self.authRepository = authRepository
    }

    func execute(novelId: String) async throws -> NovelDetails {
        let userId = try? await authRepository.getCurrentUser()?.id
        return try await repository.getNovelDetails(id: novelId, userId: userId)
    }
}
