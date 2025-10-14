//
//  HomeViewModel.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var novels: [Novel] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    @Published var hasMore: Bool = false

    private var currentCursor: String?
    private let getTeVaGustarUseCase: GetTeVaGustarUseCaseProtocol

    init(getTeVaGustarUseCase: GetTeVaGustarUseCaseProtocol) {
        self.getTeVaGustarUseCase = getTeVaGustarUseCase
    }

    convenience init() {
        self.init(getTeVaGustarUseCase: DIContainer.shared.getTeVaGustarUseCase)
    }

    func loadNovels() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await getTeVaGustarUseCase.execute(cursor: nil, limit: 20)
            novels = response.novels
            currentCursor = response.cursor
            hasMore = response.hasMore
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore, let cursor = currentCursor else { return }

        isLoadingMore = true

        do {
            let response = try await getTeVaGustarUseCase.execute(cursor: cursor, limit: 20)
            novels.append(contentsOf: response.novels)
            currentCursor = response.cursor
            hasMore = response.hasMore
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }

    func refresh() async {
        currentCursor = nil
        await loadNovels()
    }
}
