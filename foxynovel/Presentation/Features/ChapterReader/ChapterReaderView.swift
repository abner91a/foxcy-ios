//
//  ChapterReaderView.swift
//  foxynovel
//
//  Created by Claude on 14/10/25.
//

import SwiftUI

struct ChapterReaderView: View {
    // MARK: - Properties
    @StateObject private var viewModel: ChapterReaderViewModel
    @Environment(\.dismiss) private var dismiss
    let chapterId: String

    // MARK: - Initialization
    init(chapterId: String, repository: NovelRepositoryProtocol) {
        self.chapterId = chapterId
        _viewModel = StateObject(wrappedValue: ChapterReaderViewModel(repository: repository))
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                Color.readerBackground
                    .ignoresSafeArea()

                contentView
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.textPrimary)
                    }
                }

                ToolbarItem(placement: .principal) {
                    if case .success(let content) = viewModel.state {
                        Text(content.title)
                            .typography(.headline, color: .textPrimary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .task {
            await viewModel.loadChapter(id: chapterId)
        }
    }

    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                .scaleEffect(1.2)

        case .success(let content):
            readerContent(content)

        case .failure(let error):
            errorView(error)
        }
    }

    // MARK: - Reader Content
    private func readerContent(_ content: ChapterContent) -> some View {
        VStack(spacing: 0) {
            // Main reading area with LazyVStack for performance
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    // Chapter header
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(content.title)
                            .font(Typography.readerHeading)
                            .foregroundColor(.textPrimary)
                            .padding(.bottom, Spacing.xs)

                        Text("\(content.wordCount) palabras • \(content.readingTimeMinutes) min de lectura")
                            .typography(.caption, color: .textSecondary)
                    }
                    .padding(.bottom, Spacing.lg)

                    // Content segments
                    ForEach(content.contentSegments) { segment in
                        segmentView(segment)
                    }
                }
                .padding(Spacing.screenPadding)
            }

            // Navigation bar
            navigationBar(content)
        }
    }

    // MARK: - Segment View
    @ViewBuilder
    private func segmentView(_ segment: ContentSegment) -> some View {
        switch segment.type {
        case .heading:
            Text(segment.content)
                .typography(headingFont(level: segment.level ?? 1), color: .textPrimary)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xs)

        case .paragraph:
            Text(segment.content)
                .font(Typography.readerBody)
                .foregroundColor(.readerText)
                .lineSpacing(8)
                .padding(.bottom, Spacing.sm)
        }
    }

    // MARK: - Navigation Bar
    private func navigationBar(_ content: ChapterContent) -> some View {
        HStack(spacing: Spacing.md) {
            // Previous button
            Button(action: {
                Task {
                    await viewModel.navigateToPreviousChapter()
                }
            }) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chevron.left")
                    Text("Anterior")
                }
                .typography(.body, color: content.hasPreviousChapter ? .primary : .textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.cardBackground)
                .cornerRadius(CornerRadius.sm)
            }
            .disabled(!content.hasPreviousChapter)

            // Next button
            Button(action: {
                Task {
                    await viewModel.navigateToNextChapter()
                }
            }) {
                HStack(spacing: Spacing.xs) {
                    Text("Siguiente")
                    Image(systemName: "chevron.right")
                }
                .typography(.body, color: content.hasNextChapter ? .primary : .textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.cardBackground)
                .cornerRadius(CornerRadius.sm)
            }
            .disabled(!content.hasNextChapter)
        }
        .padding(Spacing.screenPadding)
        .background(Color.readerBackground)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: -2)
    }

    // MARK: - Error View
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.textSecondary)

            Text("Error al cargar el capítulo")
                .typography(.title3, color: .textPrimary)

            Text(error.localizedDescription)
                .typography(.body, color: .textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button(action: {
                Task {
                    await viewModel.loadChapter(id: chapterId)
                }
            }) {
                Text("Reintentar")
                    .typography(.body, color: .white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.primary)
                    .cornerRadius(CornerRadius.sm)
            }
        }
    }

    // MARK: - Helper Methods
    private func headingFont(level: Int) -> Font {
        switch level {
        case 1: return Typography.readerFont(size: 28)
        case 2: return Typography.readerFont(size: 24)
        case 3: return Typography.readerFont(size: 20)
        default: return Typography.readerFont(size: 18)
        }
    }
}

// MARK: - Preview
#Preview {
    ChapterReaderView(
        chapterId: "sample-id",
        repository: NovelRepositoryImpl(
            networkClient: NetworkClient()
        )
    )
}
