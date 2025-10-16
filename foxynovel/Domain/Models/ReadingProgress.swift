//
//  ReadingProgress.swift
//  foxynovel
//
//  Created by Claude on 15/10/25.
//

import SwiftData
import Foundation

@Model
class ReadingProgress {
    @Attribute(.unique) var id: String
    var novelId: String
    var novelTitle: String
    var novelCoverImage: String
    var authorName: String

    var currentChapterId: String
    var currentChapterOrder: Int
    var currentChapterTitle: String

    var progress: Double // 0.0 - 1.0 (progreso dentro del capítulo actual)
    var lastReadDate: Date
    var updatedAt: Date

    var totalChaptersRead: Int
    var totalChapters: Int

    // 🔄 Sincronización
    var needsSync: Bool // true si hay cambios no sincronizados con el servidor
    var lastSyncDate: Date?

    var progressPercentage: Double {
        guard totalChapters > 0 else { return 0.0 }
        return Double(currentChapterOrder) / Double(totalChapters)
    }

    init(
        novelId: String,
        novelTitle: String,
        novelCoverImage: String,
        authorName: String,
        currentChapterId: String,
        currentChapterOrder: Int,
        currentChapterTitle: String,
        totalChapters: Int
    ) {
        self.id = UUID().uuidString
        self.novelId = novelId
        self.novelTitle = novelTitle
        self.novelCoverImage = novelCoverImage
        self.authorName = authorName
        self.currentChapterId = currentChapterId
        self.currentChapterOrder = currentChapterOrder
        self.currentChapterTitle = currentChapterTitle
        self.progress = 0.0
        self.lastReadDate = Date()
        self.updatedAt = Date()
        self.totalChaptersRead = 1
        self.totalChapters = totalChapters
        self.needsSync = true
        self.lastSyncDate = nil
    }
}
