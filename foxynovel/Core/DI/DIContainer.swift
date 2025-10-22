//
//  DIContainer.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation
import SwiftData
import OSLog

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
            Logger.databaseLog("📦", "[DIContainer] Initializing ModelContainer with migration plan...")

            let container = try ModelContainer(
                for: ReadingProgress.self,
                migrationPlan: ReadingProgressMigrationPlan.self, // ✅ Migration support
                configurations: ModelConfiguration(
                    isStoredInMemoryOnly: false
                )
            )

            Logger.databaseLog("✅", "[DIContainer] ModelContainer initialized successfully")
            Logger.debug("   Schema version: \(container.schema.encodingVersion)", category: Logger.database)
            Logger.debug("   Migration plan: ReadingProgressMigrationPlan", category: Logger.database)

            return container
        } catch {
            Logger.error("[DIContainer] Failed to initialize ModelContainer: \(error)", category: Logger.database)
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }()

    lazy var readingProgressRepository: ReadingProgressRepository = {
        // ✅ Safe casting con mensajes de error descriptivos
        guard let client = networkClient as? NetworkClient else {
            #if DEBUG
            fatalError("❌ DI Configuration Error: NetworkClient implementation mismatch. Expected NetworkClient, got \(type(of: networkClient))")
            #else
            fatalError("Critical initialization error. Please reinstall the app.")
            #endif
        }

        guard let manager = tokenManager as? TokenManager else {
            #if DEBUG
            fatalError("❌ DI Configuration Error: TokenManager implementation mismatch. Expected TokenManager, got \(type(of: tokenManager))")
            #else
            fatalError("Critical initialization error. Please reinstall the app.")
            #endif
        }

        return ReadingProgressRepositoryImpl(
            modelContext: modelContainer.mainContext,
            networkClient: client,
            tokenManager: manager
        )
    }()
}
