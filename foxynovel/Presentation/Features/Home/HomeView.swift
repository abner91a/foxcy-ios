//
//  HomeView.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.sectionSpacing) {
                    // Header
                    headerSection

                    // Main Content
                    if viewModel.isLoading && viewModel.novels.isEmpty {
                        loadingView
                    } else if let error = viewModel.errorMessage, viewModel.novels.isEmpty {
                        errorView(message: error)
                    } else {
                        novelsSection
                    }
                }
                .padding(.vertical, Spacing.md)
            }
            .background(Color.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                if viewModel.novels.isEmpty {
                    await viewModel.loadNovels()
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FoxyNovel")
                    .typography(Typography.headlineMedium)

                Text("Descubre historias increíbles")
                    .typography(Typography.bodyMedium, color: .textSecondary)
            }

            Spacer()

            // Profile/Menu button
            Button {
                // Navigate to profile
            } label: {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accent)
            }
        }
        .padding(.horizontal, Spacing.screenPadding)
    }

    // MARK: - Novels Section
    private var novelsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Te va a gustar")
                .typography(Typography.titleLarge)
                .padding(.horizontal, Spacing.screenPadding)

            // Horizontal Scroll for novels
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.md) {
                    ForEach(viewModel.novels) { novel in
                        NavigationLink(destination: NovelDetailsView(novelId: novel.id)) {
                            NovelCard(novel: novel)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Load more indicator
                    if viewModel.hasMore {
                        loadMoreView
                    }
                }
                .padding(.horizontal, Spacing.screenPadding)
            }

            // Grid view (optional alternative)
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: Spacing.md
            ) {
                ForEach(viewModel.novels) { novel in
                    NavigationLink(destination: NovelDetailsView(novelId: novel.id)) {
                        NovelCard(novel: novel)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Cargando novelas...")
                .typography(Typography.bodyMedium, color: .textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.error)

            Text("Error")
                .typography(Typography.titleLarge)

            Text(message)
                .typography(Typography.bodyMedium, color: .textSecondary)
                .multilineTextAlignment(.center)

            PrimaryButton("Reintentar") {
                Task {
                    await viewModel.loadNovels()
                }
            }
            .padding(.horizontal, Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Load More View
    private var loadMoreView: some View {
        VStack {
            if viewModel.isLoadingMore {
                ProgressView()
            } else {
                Button {
                    Task {
                        await viewModel.loadMore()
                    }
                } label: {
                    Text("Cargar más")
                        .typography(Typography.bodyMedium, color: .accent)
                }
            }
        }
        .frame(width: 120, height: 180)
    }
}

#Preview {
    HomeView()
}
