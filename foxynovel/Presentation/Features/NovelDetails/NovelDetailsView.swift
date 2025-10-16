//
//  NovelDetailsView.swift
//  foxynovel
//
//  Created by Claude on 14/10/25.
//

import SwiftUI

struct NovelDetailsView: View {
    let novelId: String
    @StateObject private var viewModel = NovelDetailsViewModel()
    @StateObject private var chapterReaderViewModel = ChapterReaderViewModel(
        repository: DIContainer.shared.novelRepository
    )
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChapterId: String?
    @State private var showingChapterReader = false
    @State private var savedProgress: ReadingProgress?

    private let progressRepository = DIContainer.shared.readingProgressRepository

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else if let novel = viewModel.novelDetails {
                VStack(spacing: Spacing.lg) {
                    // Header with cover image
                    headerSection(novel)

                    // Content section
                    VStack(spacing: Spacing.lg) {
                        // Title and author
                        titleSection(novel)

                        // Stats row
                        statsSection(novel)

                        // Action buttons
                        actionButtons

                        // Description
                        descriptionSection(novel)

                        // Genre and Tags
                        genreTagsSection(novel)

                        // Chapters preview
                        chaptersPreviewSection(novel)
                    }
                    .padding(.horizontal, Spacing.screenPadding)
                }
            }
        }
        .background(Color.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadNovelDetails(id: novelId)
            // Cargar progreso guardado
            savedProgress = await progressRepository.getProgress(novelId: novelId)
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
        .id(novelId)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Header Section
    private func headerSection(_ novel: NovelDetails) -> some View {
        ZStack(alignment: .bottom) {
            // Cover image with gradient overlay
            AsyncImage(url: URL(string: novel.coverImage)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
            }
            .frame(height: 400)
            .clipped()

            // Gradient overlay
            LinearGradient(
                colors: [Color.clear, Color.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
        }
        .frame(maxWidth: .infinity)
        .edgesIgnoringSafeArea(.top)
    }

    // MARK: - Title Section
    private func titleSection(_ novel: NovelDetails) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(novel.title)
                .typography(Typography.displaySmall)
                .multilineTextAlignment(.leading)

            HStack(spacing: Spacing.xs) {
                if let profileImage = novel.author.profileImage, !profileImage.isEmpty {
                    AsyncImage(url: URL(string: profileImage)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.secondary.opacity(0.3))
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                }

                Text("Por \(novel.author.username)")
                    .typography(Typography.bodyMedium, color: .textSecondary)

                Spacer()

                // Status badge
                Text(novel.status == .completed ? "Completada" : "En curso")
                    .typography(Typography.labelSmall)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(novel.status == .completed ? Color.success.opacity(0.2) : Color.accent.opacity(0.2))
                    .foregroundColor(novel.status == .completed ? Color.success : Color.accent)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Stats Section
    private func statsSection(_ novel: NovelDetails) -> some View {
        HStack(spacing: Spacing.lg) {
            statItem(
                icon: "star.fill",
                value: String(format: "%.1f", novel.rating),
                label: "\(novel.ratingsCount) valoraciones"
            )

            Divider()
                .frame(height: 30)

            statItem(
                icon: "eye.fill",
                value: formatNumber(novel.views),
                label: "vistas"
            )

            Divider()
                .frame(height: 30)

            statItem(
                icon: "book.fill",
                value: "\(novel.chaptersCount)",
                label: "capítulos"
            )
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .background(Color.surface)
        .cornerRadius(16)
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.accent)
                Text(value)
                    .typography(Typography.titleMedium)
            }
            Text(label)
                .typography(Typography.labelSmall, color: .textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            // Primary action: Continue reading or Start
            if let progress = savedProgress {
                PrimaryButton("Continuar leyendo - Cap. \(progress.currentChapterOrder)") {
                    selectedChapterId = progress.currentChapterId
                    showingChapterReader = true
                }
            } else {
                PrimaryButton(viewModel.chapters.isEmpty ? "Empezar a leer" : "Empezar a leer") {
                    if let chapter = viewModel.startReading() {
                        selectedChapterId = chapter.id
                        showingChapterReader = true
                    }
                }
                .disabled(viewModel.chapters.isEmpty)
            }

            // Secondary actions
            HStack(spacing: Spacing.sm) {
                secondaryButton(
                    icon: viewModel.isFavorite ? "heart.fill" : "heart",
                    label: "Favorito",
                    color: viewModel.isFavorite ? .red : .textSecondary
                ) {
                    Task {
                        await viewModel.toggleFavorite()
                    }
                }

                secondaryButton(
                    icon: viewModel.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                    label: "Me gusta",
                    color: viewModel.isLiked ? .accent : .textSecondary
                ) {
                    Task {
                        await viewModel.toggleLike()
                    }
                }

                secondaryButton(
                    icon: "square.and.arrow.up",
                    label: "Compartir",
                    color: .textSecondary
                ) {
                    viewModel.shareNovel()
                }
            }
        }
    }

    private func secondaryButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .typography(Typography.labelMedium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .foregroundColor(color)
            .background(Color.surface)
            .cornerRadius(12)
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Cargando detalles...")
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
                    await viewModel.loadNovelDetails(id: novelId)
                }
            }
            .padding(.horizontal, Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Description Section
    private func descriptionSection(_ novel: NovelDetails) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Sinopsis")
                .typography(Typography.titleMedium)

            Text(novel.description)
                .typography(Typography.bodyMedium, color: .textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Genre and Tags Section
    private func genreTagsSection(_ novel: NovelDetails) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Género y Etiquetas")
                .typography(Typography.titleMedium)

            // Genre
            Text(novel.genre.name)
                .typography(Typography.labelMedium)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(Color.accent.opacity(0.2))
                .foregroundColor(.accent)
                .cornerRadius(16)

            // Tags
            if !novel.tags.isEmpty {
                FlowLayout(spacing: Spacing.xs) {
                    ForEach(novel.tags) { tag in
                        Text(tag.name)
                            .typography(Typography.labelSmall)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 4)
                            .background(Color.surface)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Chapters Preview Section
    private func chaptersPreviewSection(_ novel: NovelDetails) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Capítulos")
                    .typography(Typography.titleMedium)

                Spacer()

                Text("\(novel.chaptersCount) capítulos")
                    .typography(Typography.labelMedium, color: .textSecondary)
            }

            // Show first 5 chapters
            if viewModel.chapters.isEmpty {
                Text("No hay capítulos disponibles")
                    .typography(Typography.bodyMedium, color: .textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Spacing.lg)
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(Array(viewModel.chapters.prefix(5).enumerated()), id: \.element.id) { _, chapter in
                        ChapterRow(chapter: chapter) {
                            selectedChapterId = chapter.id
                            showingChapterReader = true
                        }
                    }
                }

                // View all chapters button
                if novel.chaptersCount > 5 {
                    NavigationLink(destination: ChaptersListView(
                        novelId: novelId,
                        novelTitle: novel.title,
                        viewModel: viewModel
                    )) {
                        HStack {
                            Text("Ver todos los capítulos")
                                .typography(Typography.bodyLarge)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .foregroundColor(.accent)
                        .background(Color.surface)
                        .cornerRadius(12)
                    }
                    .padding(.top, Spacing.xs)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Helpers
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000.0)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        }
        return "\(number)"
    }
}

// MARK: - FlowLayout Helper
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    NavigationStack {
        NovelDetailsView(novelId: "0198f4f3-fb02-7781-b0d6-0c014b868bb8")
    }
}
