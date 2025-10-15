//
//  ReaderSettingsSheet.swift
//  foxynovel
//
//  Created by Claude on 14/10/25.
//

import SwiftUI

struct ReaderSettingsSheet: View {
    @Binding var preferences: ReadingPreferences
    let onDismiss: () -> Void

    @State private var localPreferences: ReadingPreferences

    init(preferences: Binding<ReadingPreferences>, onDismiss: @escaping () -> Void) {
        self._preferences = preferences
        self.onDismiss = onDismiss
        self._localPreferences = State(initialValue: preferences.wrappedValue)
    }

    var body: some View {
        NavigationView {
            Form {
                // Theme Section
                Section {
                    ForEach(ReadingTheme.allCases, id: \.self) { theme in
                        Button(action: {
                            withAnimation {
                                localPreferences.theme = theme
                            }
                        }) {
                            HStack {
                                Circle()
                                    .fill(theme.backgroundColor)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(theme.textColor.opacity(0.3), lineWidth: 1)
                                    )

                                Text(theme.displayName)
                                    .foregroundColor(localPreferences.theme.textColor)

                                Spacer()

                                if localPreferences.theme == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .font(.body.weight(.semibold))
                                }
                            }
                        }
                    }
                } header: {
                    Text("Tema")
                } footer: {
                    Text("Elige el tema que más te guste para leer")
                }

                // Font Family Section
                Section {
                    ForEach(FontFamily.allCases, id: \.self) { family in
                        Button(action: {
                            localPreferences.fontFamily = family
                        }) {
                            HStack {
                                Text("Aa")
                                    .font(family.font(size: 20))
                                    .foregroundColor(localPreferences.theme.textColor)

                                Text(family.displayName)
                                    .foregroundColor(localPreferences.theme.textColor)

                                Spacer()

                                if localPreferences.fontFamily == family {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .font(.body.weight(.semibold))
                                }
                            }
                        }
                    }
                } header: {
                    Text("Familia de Fuente")
                } footer: {
                    Text("Selecciona el tipo de fuente para el texto")
                }

                // Font Size Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("A")
                                .font(.system(size: 14))
                                .foregroundColor(localPreferences.theme.secondaryTextColor)

                            Slider(value: $localPreferences.fontSize, in: 12...32, step: 1)
                                .accentColor(.accentColor)

                            Text("A")
                                .font(.system(size: 22))
                                .foregroundColor(localPreferences.theme.secondaryTextColor)
                        }

                        Text("Ejemplo de texto con este tamaño")
                            .font(localPreferences.fontFamily.font(size: localPreferences.fontSize))
                            .foregroundColor(localPreferences.theme.textColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(localPreferences.theme.backgroundColor)
                            .cornerRadius(8)
                    }
                } header: {
                    HStack {
                        Text("Tamaño de Fuente")
                        Spacer()
                        Text("\(Int(localPreferences.fontSize))pt")
                            .foregroundColor(.secondary)
                    }
                }

                // Line Spacing Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "text.alignleft")
                                .font(.caption)
                                .foregroundColor(localPreferences.theme.secondaryTextColor)

                            Slider(value: $localPreferences.lineSpacing, in: 4...16, step: 1)
                                .accentColor(.accentColor)

                            Image(systemName: "text.alignleft")
                                .font(.body)
                                .foregroundColor(localPreferences.theme.secondaryTextColor)
                        }

                        VStack(alignment: .leading, spacing: localPreferences.lineSpacing) {
                            Text("Primera línea de ejemplo")
                            Text("Segunda línea de ejemplo")
                            Text("Tercera línea de ejemplo")
                        }
                        .font(.caption)
                        .foregroundColor(localPreferences.theme.textColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(localPreferences.theme.backgroundColor)
                        .cornerRadius(8)
                    }
                } header: {
                    HStack {
                        Text("Espaciado de Línea")
                        Spacer()
                        Text("\(Int(localPreferences.lineSpacing))pt")
                            .foregroundColor(.secondary)
                    }
                }

                // Auto-Hide Toolbar Section
                Section {
                    Toggle("Ocultar automáticamente", isOn: $localPreferences.autoHideToolbar)
                        .tint(.accentColor)

                    if localPreferences.autoHideToolbar {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Retraso")
                                Spacer()
                                Text("\(Int(localPreferences.autoHideDelay))s")
                                    .foregroundColor(.secondary)
                            }

                            Slider(value: $localPreferences.autoHideDelay, in: 1...10, step: 1)
                                .accentColor(.accentColor)
                        }
                    }
                } header: {
                    Text("Barra de Herramientas")
                } footer: {
                    Text("La barra se ocultará automáticamente después del tiempo especificado")
                }

                // Reset Section
                Section {
                    Button(action: {
                        withAnimation {
                            localPreferences = .default
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Restaurar Valores Predeterminados")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Configuración de Lectura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        preferences = localPreferences
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .background(localPreferences.theme.backgroundColor)
        }
        .preferredColorScheme(localPreferences.theme.colorScheme)
    }
}

// MARK: - Preview
#Preview {
    ReaderSettingsSheet(
        preferences: .constant(.default),
        onDismiss: {}
    )
}
