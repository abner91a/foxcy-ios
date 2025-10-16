//
//  LibraryView.swift
//  foxynovel
//
//  Created by Claude on 15/10/25.
//

import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel: LibraryViewModel
    @State private var selectedNovel: ReadingProgress?
    @State private var showingNovelDetails = false

    init() {
        let container = DIContainer.shared
        _viewModel = StateObject(wrappedValue: LibraryViewModel(
            progressRepository: container.readingProgressRepository,
            tokenManager: container.tokenManager
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else if viewModel.readingHistory.isEmpty {
                    emptyStateView
                } else {
                    libraryContent
                }
            }
            .navigationTitle("Mi Biblioteca")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    syncButton
                }
            }
            .task {
                await viewModel.loadLibrary()
            }
            .navigationDestination(isPresented: $showingNovelDetails) {
                if let novel = selectedNovel {
                    NovelDetailsView(novelId: novel.novelId)
                }
            }
        }
    }

    // MARK: - Library Content

    private var libraryContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Sync status banner
                if !viewModel.syncStatus.isEmpty {
                    syncStatusBanner
                }

                // Novels list
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.readingHistory, id: \.id) { novel in
                        LibraryNovelCard(novel: novel)
                            .onTapGesture {
                                selectedNovel = novel
                                showingNovelDetails = true
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteNovel(novel.novelId)
                                    }
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
    }

    // MARK: - Sync Button

    private var syncButton: some View {
        Button(action: {
            Task {
                await viewModel.syncWithBackend()
            }
        }) {
            HStack(spacing: 4) {
                if viewModel.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: viewModel.isAuthenticated ? "arrow.triangle.2.circlepath" : "person.crop.circle.badge.exclamationmark")
                }

                if viewModel.needsSyncCount > 0 && !viewModel.isSyncing {
                    Text("\(viewModel.needsSyncCount)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
        }
        .disabled(viewModel.isSyncing || !viewModel.isAuthenticated)
    }

    // MARK: - Sync Status Banner

    private var syncStatusBanner: some View {
        Text(viewModel.syncStatus)
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(viewModel.syncStatus.contains("✓") ? Color.green : Color.orange)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "books.vertical")
                .font(.system(size: 80))
                .foregroundColor(.textSecondary.opacity(0.5))

            VStack(spacing: 8) {
                Text("Tu biblioteca está vacía")
                    .typography(Typography.titleLarge)

                Text("Empieza a leer para ver tus novelas aquí")
                    .typography(Typography.bodyMedium, color: .textSecondary)
                    .multilineTextAlignment(.center)
            }

            if !viewModel.isAuthenticated {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.vertical, 8)

                    Text("💡 Inicia sesión para sincronizar\ntu progreso en todos tus dispositivos")
                        .typography(Typography.bodySmall, color: .textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 100)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Cargando biblioteca...")
                .typography(Typography.bodyMedium, color: .textSecondary)
        }
    }
}
