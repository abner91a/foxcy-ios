//
//  ReadingPreferences.swift
//  foxynovel
//
//  Created by Claude on 14/10/25.
//

import Foundation
import SwiftUI

// MARK: - Reading Preferences
struct ReadingPreferences: Codable, Equatable {
    var fontSize: CGFloat
    var fontFamily: FontFamily
    var lineSpacing: CGFloat
    var paragraphSpacing: CGFloat
    var theme: ReadingTheme
    var autoHideToolbar: Bool
    var autoHideDelay: TimeInterval
    var brightness: Double
    var scrollToNextChapter: Bool
    var scrollThreshold: Double

    // CodingKeys for custom encoding/decoding
    enum CodingKeys: String, CodingKey {
        case fontSize, fontFamily, lineSpacing, paragraphSpacing
        case theme, autoHideToolbar, autoHideDelay, brightness
        case scrollToNextChapter, scrollThreshold
    }

    // Custom decoder to handle migration from old data without paragraphSpacing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        fontFamily = try container.decode(FontFamily.self, forKey: .fontFamily)
        lineSpacing = try container.decode(CGFloat.self, forKey: .lineSpacing)

        // Migration: Use default value if paragraphSpacing doesn't exist in old data
        paragraphSpacing = try container.decodeIfPresent(CGFloat.self, forKey: .paragraphSpacing) ?? 16

        theme = try container.decode(ReadingTheme.self, forKey: .theme)
        autoHideToolbar = try container.decode(Bool.self, forKey: .autoHideToolbar)
        autoHideDelay = try container.decode(TimeInterval.self, forKey: .autoHideDelay)
        brightness = try container.decode(Double.self, forKey: .brightness)
        scrollToNextChapter = try container.decode(Bool.self, forKey: .scrollToNextChapter)
        scrollThreshold = try container.decode(Double.self, forKey: .scrollThreshold)
    }

    // Custom encoder for symmetry
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(fontFamily, forKey: .fontFamily)
        try container.encode(lineSpacing, forKey: .lineSpacing)
        try container.encode(paragraphSpacing, forKey: .paragraphSpacing)
        try container.encode(theme, forKey: .theme)
        try container.encode(autoHideToolbar, forKey: .autoHideToolbar)
        try container.encode(autoHideDelay, forKey: .autoHideDelay)
        try container.encode(brightness, forKey: .brightness)
        try container.encode(scrollToNextChapter, forKey: .scrollToNextChapter)
        try container.encode(scrollThreshold, forKey: .scrollThreshold)
    }

    // Manual initializer for creating instances programmatically
    init(
        fontSize: CGFloat,
        fontFamily: FontFamily,
        lineSpacing: CGFloat,
        paragraphSpacing: CGFloat,
        theme: ReadingTheme,
        autoHideToolbar: Bool,
        autoHideDelay: TimeInterval,
        brightness: Double,
        scrollToNextChapter: Bool,
        scrollThreshold: Double
    ) {
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.theme = theme
        self.autoHideToolbar = autoHideToolbar
        self.autoHideDelay = autoHideDelay
        self.brightness = brightness
        self.scrollToNextChapter = scrollToNextChapter
        self.scrollThreshold = scrollThreshold
    }

    static let `default` = ReadingPreferences(
        fontSize: 18,
        fontFamily: .serif,
        lineSpacing: 6,
        paragraphSpacing: 16,
        theme: .light,
        autoHideToolbar: true,
        autoHideDelay: 3.0,
        brightness: 1.0,
        scrollToNextChapter: false,
        scrollThreshold: 0.9
    )

    // Validation
    var validatedFontSize: CGFloat {
        min(max(fontSize, 12), 32)
    }

    var validatedLineSpacing: CGFloat {
        min(max(lineSpacing, 4), 16)
    }

    var validatedParagraphSpacing: CGFloat {
        min(max(paragraphSpacing, 8), 24)
    }

    var validatedBrightness: Double {
        min(max(brightness, 0.3), 1.0)
    }

    // Computed paragraph spacing based on font size for responsive design
    var computedParagraphSpacing: CGFloat {
        // Fórmula optimizada: 1.3x fontSize
        // Con fontSize 18: 18 * 1.3 = 23.4pt
        // Total gap con lineSpacing 6: 6 + 23.4 = 29.4pt (óptimo para lectura)
        // Similar a Kindle/Wattpad/Apple Books
        let basedOnFont = validatedFontSize * 1.3
        return max(16, min(basedOnFont, 36))
    }
}

// MARK: - Font Family
enum FontFamily: String, Codable, CaseIterable {
    case serif = "Serif"
    case sansSerif = "Sans-Serif"
    case monospace = "Monospace"

    var displayName: String {
        rawValue
    }

    var fontDesign: Font.Design {
        switch self {
        case .serif:
            return .serif
        case .sansSerif:
            return .default
        case .monospace:
            return .monospaced
        }
    }

    func font(size: CGFloat) -> Font {
        return Font.system(size: size, design: fontDesign)
    }
}

// MARK: - Reading Theme
enum ReadingTheme: String, Codable, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case sepia = "Sepia"

    var displayName: String {
        rawValue
    }

    var backgroundColor: Color {
        switch self {
        case .light:
            return Color(red: 1.0, green: 1.0, blue: 1.0) // #FFFFFF
        case .dark:
            return Color(red: 0.11, green: 0.11, blue: 0.12) // #1C1C1E
        case .sepia:
            return Color(red: 0.957, green: 0.933, blue: 0.839) // #F4EED6
        }
    }

    var textColor: Color {
        switch self {
        case .light:
            return Color(red: 0.0, green: 0.0, blue: 0.0) // #000000
        case .dark:
            return Color(red: 1.0, green: 1.0, blue: 1.0) // #FFFFFF
        case .sepia:
            return Color(red: 0.357, green: 0.275, blue: 0.212) // #5B4636
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .light:
            return Color(red: 0.4, green: 0.4, blue: 0.4) // #666666
        case .dark:
            return Color(red: 0.6, green: 0.6, blue: 0.6) // #999999
        case .sepia:
            return Color(red: 0.5, green: 0.4, blue: 0.3) // #7F6650
        }
    }

    var isDark: Bool {
        self == .dark
    }

    var colorScheme: ColorScheme {
        isDark ? .dark : .light
    }
}

// MARK: - UserDefaults Extension for ReadingPreferences
extension UserDefaults {
    private static let preferencesKey = "readingPreferences"

    var readingPreferences: ReadingPreferences {
        get {
            guard let data = data(forKey: Self.preferencesKey),
                  let preferences = try? JSONDecoder().decode(ReadingPreferences.self, from: data) else {
                return .default
            }
            return preferences
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                set(data, forKey: Self.preferencesKey)
            }
        }
    }
}
