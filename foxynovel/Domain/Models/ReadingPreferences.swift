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
    var theme: ReadingTheme
    var autoHideToolbar: Bool
    var autoHideDelay: TimeInterval
    var brightness: Double
    var scrollToNextChapter: Bool
    var scrollThreshold: Double

    static let `default` = ReadingPreferences(
        fontSize: 18,
        fontFamily: .serif,
        lineSpacing: 8,
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

    var validatedBrightness: Double {
        min(max(brightness, 0.3), 1.0)
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
