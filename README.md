# 📚 FoxyNovel iOS

Una aplicación iOS profesional para lectura de novelas, construida con **SwiftUI** y **Clean Architecture**.

## 🏗️ Arquitectura

El proyecto sigue **Clean Architecture + MVVM** con separación en 3 capas principales:

```
📁 foxynovel/
├── 📁 Core/                    # Infraestructura base
│   ├── Networking/             # Cliente HTTP + Endpoints
│   ├── Storage/                # TokenManager + Keychain
│   ├── DI/                     # Dependency Injection Container
│   └── Extensions/             # Swift & SwiftUI Extensions
│
├── 📁 Domain/                  # Capa de Dominio
│   ├── Models/                 # Entidades de negocio
│   ├── Repositories/           # Protocolos de repositorios
│   └── UseCases/               # Casos de uso
│
├── 📁 Data/                    # Capa de Datos
│   ├── Remote/                 # API DTOs + Services
│   ├── Local/                  # SwiftData Models
│   └── Repositories/           # Implementaciones
│
└── 📁 Presentation/            # Capa de Presentación
    ├── Common/                 # Componentes reutilizables
    ├── Features/               # Features modulares
    └── Theme/                  # Design System
```

## ✨ Features Implementadas

### ✅ Core Layer
- **Networking**: Cliente HTTP con async/await
- **Error Handling**: Manejo centralizado de errores
- **Token Management**: JWT con Keychain para seguridad
- **Dependency Injection**: Container simple y eficiente
- **Extensions**: Utilidades para View, String, etc.

### ✅ Domain Layer
- **Modelos**: Novel, NovelDetails, ChapterContent, User
- **Repositories**: Protocolos para Auth, Novel, Chapter
- **Use Cases**: LoginUseCase, GetTeVaGustarUseCase, GetNovelDetailsUseCase

### ✅ Data Layer
- **DTOs**: AuthDTOs, NovelDTOs con mappers a dominio
- **Endpoints**: AuthEndpoints, NovelEndpoints
- **Repository Implementations**: AuthRepositoryImpl, NovelRepositoryImpl

### ✅ Presentation Layer
- **Design System**:
  - Colors: Soporte para Dark/Light mode
  - Typography: Escala tipográfica completa
  - Spacing: Sistema de 8pt grid
  - Components: NovelCard, PrimaryButton, CustomTextField

- **Features**:
  - **Auth**: Login con validación
  - **Home**: Carruseles de novelas + Infinite scroll
  - **Tab Navigation**: 4 tabs (Home, Library, Search, Profile)

## 🛠️ Stack Tecnológico

- **UI Framework**: SwiftUI (iOS 16+)
- **Arquitectura**: Clean Architecture + MVVM
- **Networking**: URLSession con async/await
- **Storage**: Keychain + SwiftData
- **Dependency Injection**: Protocol-based DI Container
- **Imágenes**: AsyncImage nativo (Kingfisher pendiente)

## 🚀 Cómo Ejecutar

### Requisitos
- Xcode 15.0+
- iOS 16.0+
- macOS Ventura+

### Instalación

1. **Clona el repositorio**
```bash
git clone <repository-url>
cd foxynovel
```

2. **Abre el proyecto en Xcode**
```bash
open foxynovel.xcodeproj
```

3. **Configura el backend**
   - Asegúrate de que tu backend esté corriendo en `http://localhost:3001`
   - O modifica la `baseURL` en `Core/Networking/Endpoint.swift`

4. **Compila y ejecuta**
   - Selecciona un simulador o dispositivo
   - Presiona `Cmd + R`

## 🔗 Integración con Backend

### Base URL
```swift
http://localhost:3001/api
```

### Endpoints Implementados

#### Auth
- `POST /v1/auth/login` - Login de usuario
- `POST /v1/auth/register` - Registro de usuario
- `GET /v1/auth/me` - Obtener usuario actual

#### Novels
- `GET /v1/home/tevagustar` - Obtener recomendaciones
- `GET /v1/detallesNovelsapp/:id` - Detalles de novela
- `POST /v1/userinterationNovelapp/favorite` - Toggle favorito
- `POST /v1/userinterationNovelapp/like` - Toggle like

## 📋 Próximas Features

### Alta Prioridad
- [ ] Novel Details Screen
- [ ] Chapter Reader con typography optimizada
- [ ] Integración de Kingfisher para caching de imágenes
- [ ] SwiftData para favoritos y historial local

### Media Prioridad
- [ ] Library Feature (Favoritos + Historial)
- [ ] Search Feature
- [ ] Profile Feature
- [ ] Notificaciones push

### Baja Prioridad
- [ ] Comentarios en novelas
- [ ] Sistema de rankings
- [ ] Compartir novelas
- [ ] Modo offline

## 🎨 Design System

### Colors
```swift
Color.primary           // Color primario de la app
Color.accent            // Color de acento (naranja)
Color.background        // Fondo principal (adaptive)
Color.textPrimary       // Texto principal (adaptive)
Color.readerBackground  // Fondo del lector
```

### Typography
```swift
Typography.displayLarge     // 57pt, bold
Typography.headlineMedium   // 28pt, semibold
Typography.titleLarge       // 22pt, medium
Typography.bodyLarge        // 16pt, regular
Typography.readerBody       // 18pt, serif
```

### Spacing
```swift
Spacing.xs      // 4pt
Spacing.sm      // 8pt
Spacing.md      // 16pt
Spacing.lg      // 24pt
Spacing.xl      // 32pt
Spacing.xxl     // 48pt
```

## 🧪 Testing

### Unit Tests (Pendiente)
```bash
# Ejecutar tests
Cmd + U
```

### Test Coverage Goals
- ViewModels: 80%+
- Use Cases: 90%+
- Repositories: 70%+

## 📝 Convenciones de Código

### Naming
- **Files**: PascalCase (e.g., `LoginViewModel.swift`)
- **Types**: PascalCase (e.g., `struct Novel`)
- **Functions**: camelCase (e.g., `func loadNovels()`)
- **Variables**: camelCase (e.g., `var isLoading`)

### Organization
- Agrupación por Feature (no por tipo)
- MARK comments para secciones
- Extensions en archivos separados cuando es extenso

### SwiftUI
- `@StateObject` para ViewModels
- `@Published` para propiedades observables
- `@MainActor` para ViewModels
- async/await para operaciones asíncronas

## 🤝 Contribuciones

1. Fork el proyecto
2. Crea una rama (`git checkout -b feature/amazing-feature`)
3. Commit tus cambios (`git commit -m 'Add amazing feature'`)
4. Push a la rama (`git push origin feature/amazing-feature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto es privado y propietario.

## 👨‍💻 Autor

**Abner** - iOS Developer

---

## 🔧 Troubleshooting

### Error: "Could not connect to localhost"
- Verifica que el backend esté corriendo
- En simulador, usa `http://localhost:3001`
- En dispositivo real, usa la IP de tu Mac (e.g., `http://192.168.1.100:3001`)

### Error: "Keychain access denied"
- Ve a Signing & Capabilities
- Habilita Keychain Sharing

### Build errors
```bash
# Limpia el proyecto
Cmd + Shift + K

# Limpia build folder
Cmd + Option + Shift + K

# Recompila
Cmd + B
```

## 📚 Recursos

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Clean Architecture - Alexey Naumov](https://nalexn.github.io/clean-architecture-swiftui/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

---

**¡Disfruta leyendo con FoxyNovel! 🦊📖**
