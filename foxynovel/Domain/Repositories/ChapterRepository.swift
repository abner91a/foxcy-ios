//
//  ChapterRepository.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

protocol ChapterRepositoryProtocol {
    func getChapterContent(chapterId: String) async throws -> ChapterContent
    func getChaptersList(novelId: String, page: Int) async throws -> [ChapterInfo]
    func markChapterAsRead(chapterId: String) async throws
    func saveReadingProgress(chapterId: String, position: Int, percentage: Float) async throws
}
