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
    @State private var preferences: ReadingPreferences
    @State private var isToolbarVisible = true
    @State private var showSettings = false
    @State private var autoHideTask: Task<Void, Never>?

    let chapterId: String

    // MARK: - Initialization
    init(chapterId: String, repository: NovelRepositoryProtocol) {
        self.chapterId = chapterId
        _viewModel = StateObject(wrappedValue: ChapterReaderViewModel(repository: repository))
        _preferences = State(initialValue: UserDefaults.standard.readingPreferences)
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background with theme color
            preferences.theme.backgroundColor
                .ignoresSafeArea()

            contentView

            // Floating toolbar overlay
            VStack {
                if isToolbarVisible {
                    topToolbar
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.25), value: isToolbarVisible)
                }

                Spacer()

                if isToolbarVisible {
                    bottomToolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.25), value: isToolbarVisible)
                }
            }
        }
        .preferredColorScheme(preferences.theme.colorScheme)
        .statusBar(hidden: !isToolbarVisible)
        .task {
            await viewModel.loadChapter(id: chapterId)
            startAutoHideTimer()
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet(
                preferences: $preferences,
                onDismiss: {
                    showSettings = false
                    savePreferences()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: preferences) { _, newPreferences in
            savePreferences()
            if newPreferences.autoHideToolbar {
                restartAutoHideTimer()
            }
        }
    }

    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(preferences.theme.textColor)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            if case .success(let content) = viewModel.state {
                Text("Capítulo \(content.chapterOrder)")
                    .font(.headline)
                    .foregroundColor(preferences.theme.textColor)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { showSettings = true }) {
                Image(systemName: "textformat.size")
                    .font(.title3)
                    .foregroundColor(preferences.theme.textColor)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(preferences.theme.backgroundColor.opacity(0.95))
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
    }

    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            if case .success = viewModel.state {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(preferences.theme.secondaryTextColor.opacity(0.2))
                            .frame(height: 2)

                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * CGFloat(viewModel.readingProgress), height: 2)
                    }
                }
                .frame(height: 2)
            }

            HStack(spacing: 12) {
                // Previous button
                Button(action: {
                    Task {
                        await viewModel.navigateToPreviousChapter()
                        restartAutoHideTimer()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundColor(canNavigatePrevious ? preferences.theme.textColor : preferences.theme.secondaryTextColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .disabled(!canNavigatePrevious)

                Divider()
                    .frame(height: 24)

                // Theme toggle button
                Button(action: {
                    toggleTheme()
                    restartAutoHideTimer()
                }) {
                    Image(systemName: preferences.theme == .dark ? "sun.max.fill" : "moon.fill")
                        .font(.body.weight(.semibold))
                        .foregroundColor(preferences.theme.textColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }

                Divider()
                    .frame(height: 24)

                // Settings button
                Button(action: {
                    showSettings = true
                    cancelAutoHideTimer()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.body.weight(.semibold))
                        .foregroundColor(preferences.theme.textColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }

                Divider()
                    .frame(height: 24)

                // Next button
                Button(action: {
                    Task {
                        await viewModel.navigateToNextChapter()
                        restartAutoHideTimer()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundColor(canNavigateNext ? preferences.theme.textColor : preferences.theme.secondaryTextColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .disabled(!canNavigateNext)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(preferences.theme.backgroundColor.opacity(0.95))
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: -2)
        }
    }

    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingPlaceholder

        case .success(let content):
            readerContent(content)

        case .failure(let error):
            errorView(error)
        }
    }

    // MARK: - Reader Content
    private func readerContent(_ content: ChapterContent) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: preferences.validatedLineSpacing) {
                // Chapter metadata only (title removed to avoid duplication with toolbar)
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(content.wordCount) palabras • \(content.readingTimeMinutes) min de lectura")
                        .font(.caption)
                        .foregroundColor(preferences.theme.secondaryTextColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 24)

                // Content segments
                ForEach(Array(content.contentSegments.enumerated()), id: \.offset) { index, segment in
                    segmentView(segment)
                        .onAppear {
                            viewModel.updateReadingProgress(segmentIndex: index, totalSegments: content.contentSegments.count)
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, isToolbarVisible ? 56 : 20)
            .padding(.bottom, isToolbarVisible ? 72 : 20)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                isToolbarVisible.toggle()
            }
            if isToolbarVisible {
                startAutoHideTimer()
            } else {
                cancelAutoHideTimer()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50, coordinateSpace: .local)
                .onEnded { value in
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height

                    // Only trigger if horizontal swipe is dominant
                    if abs(horizontalAmount) > abs(verticalAmount) {
                        if horizontalAmount > 0 && canNavigatePrevious {
                            // Swipe right -> previous chapter
                            Task {
                                await viewModel.navigateToPreviousChapter()
                            }
                        } else if horizontalAmount < 0 && canNavigateNext {
                            // Swipe left -> next chapter
                            Task {
                                await viewModel.navigateToNextChapter()
                            }
                        }
                    }
                }
        )
    }

    // MARK: - Segment View
    @ViewBuilder
    private func segmentView(_ segment: ContentSegment) -> some View {
        switch segment.type {
        case .heading:
            Text(segment.content)
                .font(headingFont(level: segment.level ?? 1))
                .fontWeight(.semibold)
                .foregroundColor(preferences.theme.textColor)
                .padding(.top, 16)
                .padding(.bottom, 8)

        case .paragraph:
            Text(segment.content)
                .font(preferences.fontFamily.font(size: preferences.validatedFontSize))
                .foregroundColor(preferences.theme.textColor)
                .lineSpacing(preferences.validatedLineSpacing)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Error View
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(preferences.theme.secondaryTextColor)

            Text("Error al cargar el capítulo")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(preferences.theme.textColor)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(preferences.theme.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                Task {
                    await viewModel.loadChapter(id: chapterId)
                }
            }) {
                Text("Reintentar")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Loading Placeholder
    private var loadingPlaceholder: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Metadata skeleton
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 14)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 14)
                }
                .padding(.bottom, 24)

                // Paragraph skeletons
                ForEach(0..<10, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: preferences.validatedFontSize + 4)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: preferences.validatedFontSize + 4)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: UIScreen.main.bounds.width * 0.7, height: preferences.validatedFontSize + 4)
                    }
                    .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, isToolbarVisible ? 56 : 20)
            .padding(.bottom, isToolbarVisible ? 72 : 20)
            .overlay(shimmerOverlay)
        }
    }

    // MARK: - Shimmer Effect
    @State private var shimmerOffset: CGFloat = -1

    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            preferences.theme.textColor.opacity(0.08),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: geometry.size.width * 0.3)
                .offset(x: shimmerOffset * geometry.size.width)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        shimmerOffset = 2
                    }
                }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Helper Methods
    private func headingFont(level: Int) -> Font {
        let baseSize = preferences.validatedFontSize
        switch level {
        case 1: return preferences.fontFamily.font(size: baseSize + 10)
        case 2: return preferences.fontFamily.font(size: baseSize + 6)
        case 3: return preferences.fontFamily.font(size: baseSize + 4)
        default: return preferences.fontFamily.font(size: baseSize + 2)
        }
    }

    private var canNavigatePrevious: Bool {
        if case .success(let content) = viewModel.state {
            return content.hasPreviousChapter
        }
        return false
    }

    private var canNavigateNext: Bool {
        if case .success(let content) = viewModel.state {
            return content.hasNextChapter
        }
        return false
    }

    private func savePreferences() {
        UserDefaults.standard.readingPreferences = preferences
    }

    private func toggleTheme() {
        withAnimation {
            switch preferences.theme {
            case .light:
                preferences.theme = .dark
            case .dark:
                preferences.theme = .sepia
            case .sepia:
                preferences.theme = .light
            }
        }
    }

    // MARK: - Auto-Hide Timer
    private func startAutoHideTimer() {
        guard preferences.autoHideToolbar else { return }

        cancelAutoHideTimer()

        autoHideTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(preferences.autoHideDelay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation {
                    isToolbarVisible = false
                }
            }
        }
    }

    private func cancelAutoHideTimer() {
        autoHideTask?.cancel()
        autoHideTask = nil
    }

    private func restartAutoHideTimer() {
        if isToolbarVisible {
            startAutoHideTimer()
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
