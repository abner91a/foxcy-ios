//
//  String+Extensions.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

extension String {
    /// Validate email format
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }

    /// Validate password (at least 6 characters)
    var isValidPassword: Bool {
        return count >= 6
    }

    /// Trim whitespace and newlines
    var trimmed: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if string is empty or contains only whitespace
    var isBlank: Bool {
        return trimmed.isEmpty
    }
}
