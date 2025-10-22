//
//  ReadingProgressMigrationPlan.swift
//  foxynovel
//
//  Created by Claude on 21/10/25.
//

import SwiftData
import Foundation

/// ✅ Plan de migración para ReadingProgress
/// Describe la evolución del esquema y cómo migrar entre versiones específicas
enum ReadingProgressMigrationPlan: SchemaMigrationPlan {

    /// Todas las versiones del esquema en orden cronológico
    static var schemas: [any VersionedSchema.Type] {
        [
            ReadingProgressSchemaV1.self
            // Futuras versiones se agregarán aquí:
            // ReadingProgressSchemaV2.self,
            // ReadingProgressSchemaV3.self,
        ]
    }

    /// Etapas de migración entre versiones
    static var stages: [MigrationStage] {
        [
            // Actualmente solo tenemos V1, por lo que no hay migraciones
            // Cuando agreguemos V2, agregaremos una etapa como:
            // .lightweight(fromVersion: ReadingProgressSchemaV1.self,
            //              toVersion: ReadingProgressSchemaV2.self)

            // Para migraciones complejas que requieren lógica personalizada:
            // .custom(
            //     fromVersion: ReadingProgressSchemaV1.self,
            //     toVersion: ReadingProgressSchemaV2.self,
            //     willMigrate: { context in
            //         // Lógica pre-migración
            //     },
            //     didMigrate: { context in
            //         // Lógica post-migración
            //     }
            // )
        ]
    }
}

// MARK: - Migration Guide

/// 📚 GUÍA DE USO PARA FUTURAS MIGRACIONES:
///
/// Cuando necesites modificar el modelo ReadingProgress:
///
/// 1️⃣ CREAR NUEVA VERSIÓN DEL ESQUEMA
///    - Crea archivo ReadingProgressSchemaV2.swift
///    - Copia el modelo completo con los cambios
///    - Incrementa versionIdentifier a Schema.Version(2, 0, 0)
///
/// 2️⃣ ACTUALIZAR MIGRATION PLAN
///    - Agrega ReadingProgressSchemaV2.self al array schemas
///    - Agrega etapa de migración al array stages
///
/// 3️⃣ TIPOS DE MIGRACIÓN
///
///    A) LIGHTWEIGHT (Automática) - Para cambios simples:
///       - Agregar campos opcionales nuevos
///       - Renombrar campos (usando @Attribute)
///       - Eliminar campos
///       - Cambiar tipos compatibles
///
///       Ejemplo:
///       .lightweight(fromVersion: ReadingProgressSchemaV1.self,
///                    toVersion: ReadingProgressSchemaV2.self)
///
///    B) CUSTOM (Manual) - Para cambios complejos:
///       - Transformaciones de datos
///       - Cambios de estructura
///       - Lógica de validación
///
///       Ejemplo:
///       .custom(
///           fromVersion: ReadingProgressSchemaV1.self,
///           toVersion: ReadingProgressSchemaV2.self,
///           willMigrate: { context in
///               print("🔄 Preparando migración V1 → V2...")
///           },
///           didMigrate: { context in
///               print("✅ Migración V1 → V2 completada")
///               // Actualizar valores, validar datos, etc.
///           }
///       )
///
/// 4️⃣ TESTING
///    - Instalar versión anterior
///    - Crear datos de prueba
///    - Actualizar a nueva versión
///    - Verificar que datos se migraron correctamente
///
/// 5️⃣ NO BORRAR VERSIONES ANTIGUAS
///    - Mantener todos los ReadingProgressSchemaVX.swift
///    - Son necesarios para migración incremental
///    - Usuarios pueden saltar múltiples versiones
