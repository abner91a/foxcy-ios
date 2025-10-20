//
//  SimilarNovelCard.swift
//  foxynovel
//
//  Created by Claude on 20/10/25.
//

import SwiftUI

struct SimilarNovelCard: View {
    let novel: SimilarNovel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Cover Image
            AsyncImage(url: URL(string: novel.coverImage)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "book.closed.fill")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: 220)
            .background(Color.surface)
            .cornerRadius(CornerRadius.md)
            .clipped()

            // Title
            Text(novel.title)
                .typography(Typography.bodyMedium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // Stats Row
            HStack(spacing: Spacing.sm) {
                // Rating
                if novel.rating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.starFilled)
                        Text(String(format: "%.1f", novel.rating))
                            .typography(Typography.labelSmall, color: .textSecondary)
                    }
                }

                // Chapters count
                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.caption2)
                        .foregroundColor(.accent.opacity(0.7))
                    Text("\(novel.chaptersCount)")
                        .typography(Typography.labelSmall, color: .textSecondary)
                }
            }
        }
        .padding(Spacing.xs)
        .background(Color.surface)
        .cornerRadius(CornerRadius.md)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview
#Preview {
    SimilarNovelCard(novel: SimilarNovel(
        id: "1",
        title: "Acaso ese príncipe es una chica: La compañera esclava cautiva del malvado rey",
        coverImage: "https://cdnmovil.foxynovel.com/public/novels/test.png",
        rating: 5.0,
        chaptersCount: 904,
        similarityScore: 25
    ))
    .frame(width: 160)
    .padding()
}
