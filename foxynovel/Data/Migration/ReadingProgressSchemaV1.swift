//
//  ReadingProgressSchemaV1.swift
//  foxynovel
//
//  Created by Claude on 21/10/25.
//

import SwiftData
import Foundation

/// ✅ Version 1 del esquema de ReadingProgress
/// Representa el estado inicial del modelo antes de cualquier migración
enum ReadingProgressSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ReadingProgress.self]
    }

    @Model
    final class ReadingProgress {
        @Attribute(.unique) var id: String
        var novelId: String
        var novelTitle: String
        var novelCoverImage: String
        var authorName: String

        var currentChapterId: String
        var currentChapter: Int // Renamed from currentChapterOrder (match Android)
        var currentChapterTitle: String

        // 🎯 UX 2025: Tracking preciso y detallado
        var currentPosition: Int // Posición de scroll dentro del capítulo
        var scrollPercentage: Double? // null = sin progreso, 0.0-1.0 = progreso real
        var segmentIndex: Int // Índice del segmento en modo VERTICAL

        var lastReadDate: Date
        var updatedAt: Date

        var totalChaptersRead: Int
        var totalChapters: Int

        // 🚀 Dual Counter System for Offline-First Sync
        // Backend source of truth (total acumulado en servidor)
        var totalReadingTime: Int64
        // Delta local pendiente de sincronización
        var unsyncedDelta: Int64

        var progressPercentage: Double {
            guard totalChapters > 0 else { return 0.0 }
            return Double(currentChapter) / Double(totalChapters)
        }

        var lastReadTime: Int64 {
            Int64(lastReadDate.timeIntervalSince1970 * 1000)
        }

        init(
            novelId: String,
            novelTitle: String,
            novelCoverImage: String,
            authorName: String,
            currentChapterId: String,
            currentChapter: Int,
            currentChapterTitle: String,
            totalChapters: Int
        ) {
            self.id = UUID().uuidString
            self.novelId = novelId
            self.novelTitle = novelTitle
            self.novelCoverImage = novelCoverImage
            self.authorName = authorName
            self.currentChapterId = currentChapterId
            self.currentChapter = currentChapter
            self.currentChapterTitle = currentChapterTitle
            self.currentPosition = 0
            self.scrollPercentage = nil
            self.segmentIndex = 0
            self.lastReadDate = Date()
            self.updatedAt = Date()
            self.totalChaptersRead = 1
            self.totalChapters = totalChapters
            self.totalReadingTime = 0
            self.unsyncedDelta = 0
        }
    }
}
