//
//  SearchView.swift
//  foxynovel
//
//  Created by Claude on 24/10/25.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            searchBar

            Divider()

            // Content
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    if viewModel.searchQuery.isEmpty {
                        // Estado inicial: búsquedas recientes y géneros
                        initialStateView
                    } else if viewModel.isSearching {
                        // Cargando resultados
                        loadingView
                    } else if let error = viewModel.errorMessage {
                        // Error
                        errorView(message: error)
                    } else if viewModel.searchResults.isEmpty {
                        // Sin resultados
                        emptyResultsView
                    } else {
                        // Resultados
                        resultsView
                    }
                }
                .padding(.vertical, Spacing.md)
            }
        }
        .background(Color.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            // Activar teclado automáticamente
            isSearchFieldFocused = true
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            // Back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.accent)
            }

            // Search TextField
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textSecondary)

                TextField("Buscar novelas, autores...", text: $viewModel.searchQuery)
                    .focused($isSearchFieldFocused)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                // Clear button
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .background(Color.backgroundSecondary)
            .cornerRadius(CornerRadius.md)
        }
        .padding(.horizontal, Spacing.screenPadding)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Initial State View
    private var initialStateView: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Recent Searches
            if !viewModel.recentSearches.isEmpty {
                recentSearchesSection
            }

            // Popular Genres
            popularGenresSection
        }
    }

    // MARK: - Recent Searches Section
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Búsquedas recientes")
                    .typography(Typography.titleMedium)

                Spacer()

                Button {
                    viewModel.clearRecentSearches()
                } label: {
                    Text("Limpiar")
                        .typography(Typography.bodySmall, color: .accent)
                }
            }
            .padding(.horizontal, Spacing.screenPadding)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.recentSearches.enumerated()), id: \.offset) { index, search in
                    Button {
                        viewModel.selectRecentSearch(search)
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.textSecondary)

                            Text(search)
                                .typography(Typography.bodyMedium, color: .textPrimary)

                            Spacer()

                            Button {
                                viewModel.removeRecentSearch(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundColor(.textTertiary)
                            }
                        }
                        .padding(.horizontal, Spacing.screenPadding)
                        .padding(.vertical, Spacing.md)
                        .background(Color.background)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    if index < viewModel.recentSearches.count - 1 {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
        }
    }

    // MARK: - Popular Genres Section
    private var popularGenresSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Géneros populares")
                .typography(Typography.titleMedium)
                .padding(.horizontal, Spacing.screenPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(viewModel.popularGenres, id: \.self) { genre in
                        Button {
                            viewModel.selectGenre(genre)
                        } label: {
                            Text(genre)
                                .typography(Typography.bodyMedium, color: .accent)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(Color.accent.opacity(0.1))
                                .cornerRadius(CornerRadius.full)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenPadding)
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Buscando...")
                .typography(Typography.bodyMedium, color: .textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.error)

            Text("Algo salió mal")
                .typography(Typography.titleLarge)

            Text(message)
                .typography(Typography.bodyMedium, color: .textSecondary)
                .multilineTextAlignment(.center)

            PrimaryButton("Reintentar") {
                Task {
                    await viewModel.performSearch()
                }
            }
            .padding(.horizontal, Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.screenPadding)
        .padding(.top, 80)
    }

    // MARK: - Empty Results View
    private var emptyResultsView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.textSecondary)

            Text("No encontramos novelas")
                .typography(Typography.titleLarge)

            Text("Intenta con otro término de búsqueda")
                .typography(Typography.bodyMedium, color: .textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.screenPadding)
        .padding(.top, 80)
    }

    // MARK: - Results View
    private var resultsView: some View {
        VStack(spacing: 0) {
            // Results count
            HStack {
                Text("\(viewModel.searchResults.count) resultados")
                    .typography(Typography.bodyMedium, color: .textSecondary)

                Spacer()
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.bottom, Spacing.sm)

            // Results list
            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchResults) { novel in
                    NavigationLink(destination: NovelDetailsView(novelId: novel.id)) {
                        SearchResultRow(novel: novel)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if novel.id != viewModel.searchResults.last?.id {
                        Divider()
                            .padding(.leading, 90)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
