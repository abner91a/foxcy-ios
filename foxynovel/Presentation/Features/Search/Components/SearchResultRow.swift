//
//  SearchResultRow.swift
//  foxynovel
//
//  Created by Claude on 24/10/25.
//

import SwiftUI

/// Componente compacto para mostrar resultados de búsqueda
/// Diseño horizontal: imagen + info
struct SearchResultRow: View {
    let novel: Novel

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Cover Image
            AsyncImage(url: URL(string: novel.coverImageUrl)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "book.closed.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 60, height: 90)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(CornerRadius.sm)
            .clipped()

            // Info
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(novel.title)
                    .typography(Typography.titleSmall)
                    .lineLimit(2)

                // Author
                Text(novel.author)
                    .typography(Typography.bodySmall, color: .textSecondary)
                    .lineLimit(1)

                // Stats Row
                HStack(spacing: Spacing.sm) {
                    // Rating
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.starFilled)
                        Text(String(format: "%.1f", novel.rating))
                            .typography(Typography.labelSmall, color: .textSecondary)
                    }

                    Text("•")
                        .typography(Typography.labelSmall, color: .textSecondary)

                    // Chapters
                    Text("\(novel.chaptersCount) caps")
                        .typography(Typography.labelSmall, color: .textSecondary)

                    Text("•")
                        .typography(Typography.labelSmall, color: .textSecondary)

                    // Status
                    Text(novel.status.displayName)
                        .typography(Typography.labelSmall, color: .accent)
                }
            }

            Spacer()

            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.textTertiary)
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.screenPadding)
        .background(Color.background)
        .contentShape(Rectangle()) // Hace que toda el área sea táctil
    }
}

#Preview {
    VStack(spacing: 0) {
        SearchResultRow(novel: Novel(
            id: "1",
            title: "El Cultivo del Dragón Supremo",
            slug: "cultivo-dragon",
            author: "Chen Wei",
            description: "Una épica historia de cultivo...",
            coverImageUrl: "https://example.com/cover.jpg",
            status: .ongoing,
            rating: 4.8,
            ratingsCount: 1250,
            views: 50000,
            likes: 3200,
            chaptersCount: 245,
            commentsCount: 890,
            genres: ["Fantasía", "Acción"],
            tags: ["Cultivo", "Dragones"],
            popularityScore: 95.5,
            createdAt: "2024-01-01",
            updatedAt: "2024-10-20"
        ))

        Divider()

        SearchResultRow(novel: Novel(
            id: "2",
            title: "Romance en la Academia",
            slug: "romance-academia",
            author: "Li Mei",
            description: "Una historia de amor...",
            coverImageUrl: "https://example.com/cover2.jpg",
            status: .completed,
            rating: 4.5,
            ratingsCount: 890,
            views: 35000,
            likes: 2100,
            chaptersCount: 120,
            commentsCount: 450,
            genres: ["Romance", "Drama"],
            tags: ["Academia", "Romance"],
            popularityScore: 88.3,
            createdAt: "2024-01-15",
            updatedAt: "2024-09-30"
        ))
    }
    .background(Color.background)
}
