//
//  PrimaryButton.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    init(
        _ title: String,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .typography(Typography.titleMedium, color: .white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.accent)
            .cornerRadius(CornerRadius.md)
        }
        .disabled(isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .typography(Typography.titleMedium, color: .accent)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.accent, lineWidth: 2)
                )
        }
    }
}
