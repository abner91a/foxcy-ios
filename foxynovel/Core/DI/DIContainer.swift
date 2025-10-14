//
//  DIContainer.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

final class DIContainer {
    static let shared = DIContainer()

    private init() {}

    // MARK: - Networking
    lazy var networkClient: NetworkClientProtocol = {
        NetworkClient()
    }()

    // MARK: - Storage
    lazy var tokenManager: TokenProvider = {
        TokenManager.shared
    }()

    // MARK: - Repositories
    lazy var authRepository: AuthRepositoryProtocol = {
        AuthRepositoryImpl(
            networkClient: networkClient,
            tokenManager: tokenManager
        )
    }()

    lazy var novelRepository: NovelRepositoryProtocol = {
        NovelRepositoryImpl(networkClient: networkClient)
    }()

    // MARK: - Use Cases
    lazy var loginUseCase: LoginUseCaseProtocol = {
        LoginUseCase(repository: authRepository)
    }()

    lazy var getTeVaGustarUseCase: GetTeVaGustarUseCaseProtocol = {
        GetTeVaGustarUseCase(repository: novelRepository)
    }()

    lazy var getNovelDetailsUseCase: GetNovelDetailsUseCaseProtocol = {
        GetNovelDetailsUseCase(
            repository: novelRepository,
            authRepository: authRepository
        )
    }()
}
