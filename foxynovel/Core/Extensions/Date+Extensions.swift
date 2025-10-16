//
//  Date+Extensions.swift
//  foxynovel
//
//  Created by Claude on 15/10/25.
//

import Foundation

extension Date {
    /// Convierte la fecha a una cadena relativa (ej: "hace 2 horas", "hace 3 días")
    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "es")
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Formatea la fecha en formato corto (ej: "14/10/25")
    func shortFormat() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "es")
        return formatter.string(from: self)
    }

    /// Formatea la fecha y hora (ej: "14 oct 2025, 14:30")
    func mediumFormat() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es")
        return formatter.string(from: self)
    }
}
