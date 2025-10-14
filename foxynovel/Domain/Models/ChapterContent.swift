//
//  ChapterContent.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation
import SwiftUI

struct ChapterContent: Identifiable, Codable {
    let id: String
    let title: String
    let segments: [TextSegment]
    let wordCount: Int
    let readingTimeMinutes: Int
    let novelId: String
    let chapterOrder: Int
    let navigation: ChapterNavigation
    var userProgress: UserProgress?
}

struct ChapterNavigation: Codable {
    let previousChapterId: String?
    let nextChapterId: String?

    var hasPrevious: Bool { previousChapterId != nil }
    var hasNext: Bool { nextChapterId != nil }
}

struct TextSegment: Identifiable, Codable {
    let id = UUID()
    let type: SegmentType
    let content: String
    let level: Int?
    let spans: [TextSpan]

    var hasStyles: Bool { !spans.isEmpty }

    enum CodingKeys: String, CodingKey {
        case type, content, level, spans
    }
}

enum SegmentType: String, Codable {
    case heading = "heading"
    case paragraph = "paragraph"
}

struct TextSpan: Codable {
    let text: String
    let style: TextSpanStyle
    let range: Range<Int>
    let highlightColor: String?

    enum CodingKeys: String, CodingKey {
        case text, style, range, highlightColor
    }

    init(text: String, style: TextSpanStyle, range: Range<Int>, highlightColor: String? = nil) {
        self.text = text
        self.style = style
        self.range = range
        self.highlightColor = highlightColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        style = try container.decode(TextSpanStyle.self, forKey: .style)

        // Decode range as array [start, end]
        let rangeArray = try container.decode([Int].self, forKey: .range)
        range = rangeArray[0]..<rangeArray[1]

        highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(style, forKey: .style)
        try container.encode([range.lowerBound, range.upperBound], forKey: .range)
        try container.encodeIfPresent(highlightColor, forKey: .highlightColor)
    }
}

enum TextSpanStyle: String, Codable {
    case bold
    case italic
    case underline
    case strike
    case code
    case highlight
}

struct UserProgress: Codable {
    let lastReadPosition: Int
    let progressPercentage: Float
    let isCompleted: Bool
    let lastReadAt: Int64
}
