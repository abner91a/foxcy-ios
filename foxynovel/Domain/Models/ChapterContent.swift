//
//  ChapterContent.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

// MARK: - Main Content Model
struct ChapterContent: Identifiable, Codable {
    let id: String
    let title: String
    let contentSegments: [ContentSegment]
    let wordCount: Int
    let readingTimeMinutes: Int
    let novelId: String
    let chapterOrder: Int
    let previousChapterId: String?
    let nextChapterId: String?

    var hasPreviousChapter: Bool { previousChapterId != nil }
    var hasNextChapter: Bool { nextChapterId != nil }
}

// MARK: - Content Segment
struct ContentSegment: Identifiable, Codable {
    let id = UUID()
    let type: SegmentType
    let content: String
    let level: Int?
    let spans: [ContentSpan]

    var hasStyles: Bool { !spans.isEmpty }

    enum CodingKeys: String, CodingKey {
        case type, content, level, spans
    }
}

// MARK: - Segment Type
enum SegmentType: String, Codable {
    case heading = "heading"
    case paragraph = "paragraph"
}

// MARK: - Content Span (for styled text)
struct ContentSpan: Codable {
    let style: SpanStyle
    let start: Int
    let end: Int

    enum CodingKeys: String, CodingKey {
        case style, start, end
    }
}

// MARK: - Span Style
enum SpanStyle: String, Codable {
    case bold
    case italic
    case underline
    case strikethrough
    case highlight
}
