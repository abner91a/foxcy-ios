//
//  SearchViewModel.swift
//  foxynovel
//
//  Created by Claude on 24/10/25.
//

import Foundation
import Combine
import OSLog

@MainActor
final class SearchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var searchQuery = "" {
        didSet {
            performDebouncedSearch()
        }
    }
    @Published var searchResults: [Novel] = []
    @Published var recentSearches: [String] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let novelRepository: NovelRepositoryProtocol
    private var searchTask: Task<Void, Never>?
    private let debounceTime: TimeInterval = 0.3
    private var debounceWorkItem: DispatchWorkItem?

    // UserDefaults keys
    private let recentSearchesKey = "recentSearches"
    private let maxRecentSearches = 5

    // Géneros populares para sugerencias
    let popularGenres = [
        "Fantasía", "Romance", "Acción", "Misterio",
        "Ciencia Ficción", "Drama", "Comedia", "Terror"
    ]

    // MARK: - Initialization
    init(novelRepository: NovelRepositoryProtocol = NovelRepositoryImpl(
        networkClient: NetworkClient()
    )) {
        self.novelRepository = novelRepository
        loadRecentSearches()
    }

    // MARK: - Search Methods
    private func performDebouncedSearch() {
        // Cancelar búsqueda anterior
        debounceWorkItem?.cancel()

        // Si el query está vacío, limpiar resultados
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            errorMessage = nil
            return
        }

        // Crear nueva búsqueda con debounce
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                await self?.performSearch()
            }
        }

        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceTime, execute: workItem)
    }

    func performSearch() async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)

        guard !query.isEmpty else {
            searchResults = []
            return
        }

        // Cancelar tarea de búsqueda anterior
        searchTask?.cancel()

        isSearching = true
        errorMessage = nil

        // Crear nueva tarea de búsqueda
        searchTask = Task {
            do {
                Logger.info("[SearchViewModel] Searching for: \(query)")

                let results = try await novelRepository.searchNovels(query: query, page: 1)

                // Verificar si la tarea fue cancelada
                guard !Task.isCancelled else {
                    Logger.info("[SearchViewModel] Search cancelled")
                    return
                }

                searchResults = results
                isSearching = false

                // Guardar búsqueda reciente si hay resultados
                if !results.isEmpty {
                    saveRecentSearch(query: query)
                }

                Logger.info("[SearchViewModel] Found \(results.count) results")
            } catch {
                guard !Task.isCancelled else { return }

                Logger.error("[SearchViewModel] Search error: \(error.localizedDescription)")
                errorMessage = "Error al buscar novelas"
                searchResults = []
                isSearching = false
            }
        }

        await searchTask?.value
    }

    func selectGenre(_ genre: String) {
        searchQuery = genre
        // performSearch se ejecutará automáticamente por el didSet
    }

    func selectRecentSearch(_ search: String) {
        searchQuery = search
        // performSearch se ejecutará automáticamente por el didSet
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        errorMessage = nil
    }

    // MARK: - Recent Searches Management
    private func loadRecentSearches() {
        if let saved = UserDefaults.standard.array(forKey: recentSearchesKey) as? [String] {
            recentSearches = saved
            Logger.info("[SearchViewModel] Loaded \(saved.count) recent searches")
        }
    }

    private func saveRecentSearch(query: String) {
        // Remover si ya existe
        recentSearches.removeAll { $0.lowercased() == query.lowercased() }

        // Agregar al inicio
        recentSearches.insert(query, at: 0)

        // Limitar a máximo de búsquedas recientes
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }

        // Guardar en UserDefaults
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
        Logger.info("[SearchViewModel] Saved recent search: \(query)")
    }

    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: recentSearchesKey)
        Logger.info("[SearchViewModel] Cleared all recent searches")
    }

    func removeRecentSearch(at index: Int) {
        guard index < recentSearches.count else { return }
        recentSearches.remove(at: index)
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
    }
}
