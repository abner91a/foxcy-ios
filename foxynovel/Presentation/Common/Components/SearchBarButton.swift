//
//  SearchBarButton.swift
//  foxynovel
//
//  Created by Claude on 24/10/25.
//

import SwiftUI

/// Fake search bar button que navega a la pantalla de búsqueda
/// Diseñado para parecer un campo de búsqueda pero funciona como botón
struct SearchBarButton: View {
    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Ícono de lupa
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.textSecondary)

            // Placeholder text
            Text("Buscar novelas, autores...")
                .typography(Typography.bodyMedium, color: .textSecondary)

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 12)
        .background(Color.backgroundSecondary)
        .cornerRadius(CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.textSecondary.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        SearchBarButton()
            .padding(.horizontal, Spacing.screenPadding)

        Text("Preview: Tap para navegar a búsqueda")
            .typography(Typography.bodySmall, color: .textSecondary)
    }
    .background(Color.background)
}
