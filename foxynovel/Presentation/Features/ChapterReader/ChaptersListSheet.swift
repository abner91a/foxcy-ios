//
//  ChaptersListSheet.swift
//  foxynovel
//
//  Created by Claude on 17/10/25.
//

import SwiftUI

struct ChaptersListSheet: View {
    @ObservedObject var viewModel: ChapterReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoadingChaptersList {
                    loadingView
                } else if viewModel.allChaptersList.isEmpty {
                    emptyState
                } else {
                    chaptersList
                }
            }
            .navigationTitle("Capítulos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .task {
                if viewModel.allChaptersList.isEmpty {
                    await viewModel.loadChaptersList()
                }
            }
        }
    }

    // MARK: - Chapters List
    private var chaptersList: some View {
        List {
            ForEach(Array(filteredChapters.enumerated()), id: \.element.id) { index, chapter in
                ChapterListRow(
                    chapter: chapter,
                    isCurrent: chapter.id == viewModel.currentChapterId,
                    isRead: chapter.isRead
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    handleChapterTap(chapter)
                }
                .onAppear {
                    if shouldLoadMore(at: index) {
                        Task {
                            await viewModel.loadChaptersList(loadMore: true)
                        }
                    }
                }
            }

            // Loading indicator at bottom
            if viewModel.isLoadingChaptersList && !viewModel.allChaptersList.isEmpty {
                loadingMoreIndicator
            }
        }
        .listStyle(.plain)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Buscar capítulos..."
        )
        .onChange(of: searchText) { oldValue, newValue in
            // When user starts searching, load all chapters if needed
            if !newValue.isEmpty && viewModel.hasMoreChaptersToLoad {
                Task {
                    await loadAllChaptersForSearch()
                }
            }
        }
    }

    // MARK: - Filtered Chapters
    private var filteredChapters: [ChapterInfo] {
        if searchText.isEmpty {
            return viewModel.allChaptersList
        } else {
            return viewModel.allChaptersList.filter { chapter in
                chapter.title.localizedCaseInsensitiveContains(searchText) ||
                "Capítulo \(chapter.order)".localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Cargando capítulos...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No hay capítulos disponibles")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Vuelve pronto para ver nuevos capítulos")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Loading More Indicator
    private var loadingMoreIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
    }

    // MARK: - Helper Functions
    private func shouldLoadMore(at index: Int) -> Bool {
        // Don't trigger if searching (will load all chapters separately)
        guard searchText.isEmpty else { return false }

        // Trigger when within last 10 items
        return index >= viewModel.allChaptersList.count - 10 &&
               viewModel.hasMoreChaptersToLoad &&
               !viewModel.isLoadingChaptersList
    }

    private func loadAllChaptersForSearch() async {
        // Load all remaining chapters for complete search results
        while viewModel.hasMoreChaptersToLoad && !viewModel.isLoadingChaptersList {
            await viewModel.loadChaptersList(loadMore: true)
        }
    }

    // MARK: - Handle Chapter Tap
    private func handleChapterTap(_ chapter: ChapterInfo) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        Task {
            await viewModel.jumpToChapter(id: chapter.id)
            dismiss()
        }
    }
}

// MARK: - Chapter List Row
struct ChapterListRow: View {
    let chapter: ChapterInfo
    let isCurrent: Bool
    let isRead: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 28, height: 28)

                Image(systemName: statusIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            // Chapter info
            VStack(alignment: .leading, spacing: 4) {
                Text("Capítulo \(chapter.order)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(chapter.title)
                    .font(.body)
                    .foregroundColor(isCurrent ? .accentColor : .primary)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .lineLimit(2)

                if let wordCount = chapter.wordCount, let readingTime = chapter.readingTimeMinutes {
                    Text("\(wordCount) palabras • \(readingTime) min")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Current indicator
            if isCurrent {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        if isCurrent {
            return .blue
        } else if isRead {
            return .green
        } else {
            return .gray
        }
    }

    private var statusIcon: String {
        if isCurrent {
            return "play.fill"
        } else if isRead {
            return "checkmark"
        } else {
            return "circle"
        }
    }
}

#Preview {
    ChaptersListSheet(
        viewModel: ChapterReaderViewModel(
            repository: DIContainer.shared.novelRepository
        )
    )
}
