//
//  DIContainer.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation
import SwiftData

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

    // MARK: - SwiftData
    lazy var modelContainer: ModelContainer = {
        do {
            let container = try ModelContainer(
                for: ReadingProgress.self,
                configurations: ModelConfiguration(
                    isStoredInMemoryOnly: false
                )
            )
            return container
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }()

    lazy var readingProgressRepository: ReadingProgressRepository = {
        ReadingProgressRepositoryImpl(
            modelContext: modelContainer.mainContext,
            networkClient: networkClient as! NetworkClient,
            tokenManager: tokenManager as! TokenManager
        )
    }()
}
