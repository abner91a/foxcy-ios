//
//  ChaptersListView.swift
//  foxynovel
//
//  Created by Claude on 14/10/25.
//

import SwiftUI

struct ChaptersListView: View {
    let novelId: String
    let novelTitle: String
    @ObservedObject var viewModel: NovelDetailsViewModel
    @StateObject private var chapterReaderViewModel = ChapterReaderViewModel(
        repository: DIContainer.shared.novelRepository
    )
    @State private var selectedChapterId: String?
    @State private var showingChapterReader = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.xs) {
                if viewModel.chapters.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(viewModel.chapters.enumerated()), id: \.element.id) { index, chapter in
                        ChapterRow(chapter: chapter) {
                            selectedChapterId = chapter.id
                            showingChapterReader = true
                        }
                        .onAppear {
                            // Lazy loading: cargar más cuando estamos cerca del final
                            if index == viewModel.chapters.count - 10 {
                                Task {
                                    await viewModel.loadMoreChapters()
                                }
                            }
                        }
                    }

                    // Loading indicator at the bottom
                    if viewModel.isLoadingMoreChapters {
                        loadingIndicator
                    } else if !viewModel.hasMoreChapters && viewModel.chapters.count > 50 {
                        endMessage
                    }
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.vertical, Spacing.md)
        }
        .navigationTitle("Capítulos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await viewModel.toggleSortOrder()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.sortOrder == "asc" ? "arrow.up" : "arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                        Text(viewModel.sortOrder == "asc" ? "1→N" : "N→1")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.accent)
                }
                .disabled(viewModel.isLoadingMoreChapters)
            }
        }
        .navigationDestination(isPresented: $showingChapterReader) {
            if let chapterId = selectedChapterId, let novel = viewModel.novelDetails {
                ChapterReaderView(
                    chapterId: chapterId,
                    viewModel: chapterReaderViewModel,
                    novelId: novel.id,
                    novelTitle: novel.title,
                    novelCoverImage: novel.coverImage,
                    authorName: novel.author.username,
                    totalChapters: novel.chaptersCount
                )
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundColor(.textSecondary)

            Text("No hay capítulos disponibles")
                .typography(Typography.bodyLarge, color: .textSecondary)

            Text("Vuelve pronto para ver nuevos capítulos")
                .typography(Typography.bodySmall, color: .textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Loading Indicator
    private var loadingIndicator: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Cargando más capítulos...")
                .typography(Typography.bodySmall, color: .textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - End Message
    private var endMessage: some View {
        HStack {
            Rectangle()
                .fill(Color.textSecondary.opacity(0.3))
                .frame(height: 1)

            Text("Fin de la lista")
                .typography(Typography.labelSmall, color: .textSecondary)
                .padding(.horizontal, Spacing.sm)

            Rectangle()
                .fill(Color.textSecondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, Spacing.md)
    }
}

#Preview {
    NavigationStack {
        ChaptersListView(
            novelId: "test",
            novelTitle: "Test Novel",
            viewModel: NovelDetailsViewModel()
        )
    }
}
