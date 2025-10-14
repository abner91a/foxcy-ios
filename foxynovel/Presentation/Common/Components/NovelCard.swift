//
//  NovelCard.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import SwiftUI

struct NovelCard: View {
    let novel: Novel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
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
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 120, height: 180)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(CornerRadius.md)
            .clipped()

            // Title
            Text(novel.title)
                .typography(Typography.titleSmall)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 120, alignment: .leading)

            // Rating
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.starFilled)
                Text(String(format: "%.1f", novel.rating))
                    .typography(Typography.labelSmall, color: .textSecondary)
            }
        }
    }
}
