//
//  LibraryNovelCard.swift
//  foxynovel
//
//  Created by Claude on 15/10/25.
//

import SwiftUI

struct LibraryNovelCard: View {
    let novel: ReadingProgress

    var body: some View {
        HStack(spacing: 16) {
            // Cover Image
            AsyncImage(url: URL(string: novel.novelCoverImage)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 80, height: 120)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            // Info
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(novel.novelTitle)
                    .typography(Typography.titleMedium)
                    .lineLimit(2)

                // Author
                Text(novel.authorName)
                    .typography(Typography.bodySmall, color: .textSecondary)
                    .lineLimit(1)

                // Progress Bar
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 6)

                            // Progress
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accent, Color.accent.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * novel.progressPercentage, height: 6)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text("Capítulo \(novel.currentChapter) de \(novel.totalChapters)")
                            .typography(Typography.labelSmall, color: .textSecondary)

                        Spacer()

                        Text("\(Int(novel.progressPercentage * 100))%")
                            .typography(Typography.labelSmall)
                            .foregroundColor(.accent)
                            .fontWeight(.semibold)
                    }
                }

                // Last Read
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)

                    Text(novel.lastReadDate.timeAgo())
                        .typography(Typography.labelSmall, color: .textSecondary)

                    Spacer()

                    // Sync indicator - show if there's unsynced reading time
                    if novel.unsyncedDelta > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                            Text("Sin sync")
                                .typography(Typography.labelSmall)
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.surface)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
