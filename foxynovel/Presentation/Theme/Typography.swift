//
//  Typography.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import SwiftUI

struct Typography {
    // MARK: - Display
    static let displayLarge = Font.system(size: 57, weight: .bold)
    static let displayMedium = Font.system(size: 45, weight: .bold)
    static let displaySmall = Font.system(size: 36, weight: .bold)

    // MARK: - Headline
    static let headlineLarge = Font.system(size: 32, weight: .semibold)
    static let headlineMedium = Font.system(size: 28, weight: .semibold)
    static let headlineSmall = Font.system(size: 24, weight: .semibold)

    // MARK: - Title
    static let titleLarge = Font.system(size: 22, weight: .medium)
    static let titleMedium = Font.system(size: 16, weight: .medium)
    static let titleSmall = Font.system(size: 14, weight: .medium)

    // MARK: - Body
    static let bodyLarge = Font.system(size: 16, weight: .regular)
    static let bodyMedium = Font.system(size: 14, weight: .regular)
    static let bodySmall = Font.system(size: 12, weight: .regular)

    // MARK: - Label
    static let labelLarge = Font.system(size: 14, weight: .medium)
    static let labelMedium = Font.system(size: 12, weight: .medium)
    static let labelSmall = Font.system(size: 10, weight: .medium)

    // MARK: - Reader
    static func readerFont(size: CGFloat) -> Font {
        return Font.system(size: size, design: .serif)
    }

    static let readerBody = readerFont(size: 18)
    static let readerHeading = readerFont(size: 24)
}

// MARK: - View Extension for Typography
extension View {
    func typography(_ font: Font, color: Color = .textPrimary) -> some View {
        self
            .font(font)
            .foregroundColor(color)
    }
}
