//
//  Colors.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import SwiftUI

extension Color {
    // MARK: - Primary Colors
    static let primary = Color.blue
    static let primaryDark = Color.blue.opacity(0.8)
    static let primaryLight = Color.blue.opacity(0.3)

    // MARK: - Accent Colors
    static let accent = Color.orange
    static let accentSecondary = Color.orange.opacity(0.7)

    // MARK: - Background Colors
    static let background = Color(uiColor: .systemBackground)
    static let backgroundSecondary = Color(uiColor: .secondarySystemBackground)
    static let cardBackground = Color(uiColor: .tertiarySystemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)

    // MARK: - Text Colors
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)

    // MARK: - Reader Colors
    static let readerBackground = Color(uiColor: .systemBackground)
    static let readerText = Color(uiColor: .label)
    static let readerSepia = Color(red: 0.957, green: 0.933, blue: 0.839) // #F4EED6

    // MARK: - Semantic Colors
    static let success = Color.green
    static let error = Color.red
    static let warning = Color.orange
    static let info = Color.blue

    // MARK: - Rating
    static let starFilled = Color.yellow
    static let starEmpty = Color.gray.opacity(0.3)
}
