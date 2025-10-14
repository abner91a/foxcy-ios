//
//  ChapterRow.swift
//  foxynovel
//
//  Created by Claude on 14/10/25.
//

import SwiftUI

struct ChapterRow: View {
    let chapter: ChapterInfo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chapter.title)
                        .typography(Typography.bodyLarge)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.leading)

                    if let readingTime = chapter.readingTimeMinutes {
                        Text("\(readingTime) min de lectura")
                            .typography(Typography.labelSmall, color: .textSecondary)
                    }
                }

                Spacer()

                if chapter.isRead {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.success)
                        .font(.body)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.surface)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack {
        ChapterRow(chapter: ChapterInfo(
            id: "1",
            title: "Capítulo 1: El Comienzo",
            order: 1,
            createdAt: nil,
            wordCount: 1500,
            readingTimeMinutes: 5,
            isRead: false
        )) {}

        ChapterRow(chapter: ChapterInfo(
            id: "2",
            title: "Capítulo 2: El Encuentro",
            order: 2,
            createdAt: nil,
            wordCount: 2000,
            readingTimeMinutes: 7,
            isRead: true
        )) {}
    }
    .padding()
}
