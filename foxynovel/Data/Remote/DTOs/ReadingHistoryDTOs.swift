//
//  ReadingHistoryDTOs.swift
//  foxynovel
//
//  Created by Claude on 21/10/25.
//

import Foundation

// MARK: - Request DTOs (Upload)

/// DTO para enviar progreso de lectura al backend
/// Estructura exacta que espera el backend NestJS
struct ReadingProgressDto: Codable {
    let novelId: String
    let currentChapter: Int
    let currentPosition: Int
    let totalChaptersRead: Int
    let lastReadTime: Int64 // Timestamp en milisegundos

    // 🚀 CRÍTICO: Enviar solo unsyncedDelta (el backend lo sumará al total)
    // Backend ejecutará: totalReadingTime_backend += unsyncedDelta
    let totalReadingTime: Int64 // En realidad es unsyncedDelta

    // 🎯 UX 2025: Tracking preciso
    let currentChapterId: String?
    let scrollPercentage: Double? // null = sin progreso, 0.0-1.0 = progreso real
    let segmentIndex: Int
}

/// DTO para sincronización masiva de historial (batch upload)
struct SyncHistoryDto: Codable {
    let history: [ReadingProgressDto]
}

// MARK: - Response DTOs (Download)

/// DTO de respuesta del backend con datos enriquecidos
/// 🚀 OPTIMIZACIÓN 2025: Incluye datos de novela y autor
/// Esto elimina la necesidad de queries adicionales para obtener títulos/portadas
/// Backend retorna ReadingProgressEnrichedResponseDto que contiene todos estos campos
struct ReadingProgressResponseDto: Codable {
    let id: String
    let userId: String
    let novelId: String
    let currentChapter: Int
    let currentPosition: Int
    let totalChaptersRead: Int
    let lastReadTime: String // ISO 8601
    let totalReadingTime: String // BigInt como string
    let currentChapterId: String?
    let scrollPercentage: Double?
    let segmentIndex: Int
    let createdAt: String // ISO 8601
    let updatedAt: String // ISO 8601

    // 🚀 Datos enriquecidos de novela (siempre incluidos en GET /historia)
    // Backend usa ReadingProgressEnrichedResponseDto con estos campos REQUERIDOS
    let novelTitle: String?
    let novelCoverImage: String?
    let novelStatus: String?
    let novelChaptersCount: Int?

    // 🚀 Datos de autor
    let authorName: String?
    let authorSlug: String?
}

/// Alias para compatibilidad con backend
/// Backend retorna ReadingProgressEnrichedResponseDto en GET endpoints
/// que es idéntico a ReadingProgressResponseDto en iOS (ya incluye campos enriquecidos)
typealias ReadingProgressEnrichedResponseDto = ReadingProgressResponseDto

/// DTO de respuesta para sincronización masiva
struct SyncHistoryResponseDto: Codable {
    let synced: Int
    let failed: Int
    let details: [ReadingProgressResponseDto]
}

// MARK: - Domain Conversion Extensions

extension ReadingProgressResponseDto {
    /// Convertir ReadingProgressResponseDto a modelo de dominio ReadingProgress
    /// Parsea ISO 8601 timestamps y BigInt strings
    func toDomain() -> ReadingProgressDomain {
        return ReadingProgressDomain(
            novelId: novelId,
            currentChapter: currentChapter,
            currentPosition: currentPosition,
            totalChaptersRead: totalChaptersRead,
            lastReadTime: parseIsoToMillis(lastReadTime),
            totalReadingTime: Int64(totalReadingTime) ?? 0,
            unsyncedDelta: 0, // Después del sync, delta es 0
            currentChapterId: currentChapterId,
            scrollPercentage: scrollPercentage,
            segmentIndex: segmentIndex
        )
    }

    /// Helper para parsear ISO 8601 timestamp a milisegundos
    private func parseIsoToMillis(_ isoString: String) -> Int64 {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: isoString) {
            return Int64(date.timeIntervalSince1970 * 1000)
        }

        // Fallback sin fracción de segundos
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            return Int64(date.timeIntervalSince1970 * 1000)
        }

        // Fallback a tiempo actual si hay error
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}

// MARK: - Domain Model (Temporal)

/// Modelo de dominio temporal para progreso de lectura
/// Usado para transferir datos entre DTO y SwiftData Model
struct ReadingProgressDomain {
    let novelId: String
    let currentChapter: Int
    let currentPosition: Int
    let totalChaptersRead: Int
    let lastReadTime: Int64

    // 🚀 Dual Counter System
    let totalReadingTime: Int64 // Backend source of truth
    let unsyncedDelta: Int64 // Delta local pendiente

    // 🎯 UX 2025: Tracking preciso
    let currentChapterId: String?
    let scrollPercentage: Double?
    let segmentIndex: Int
}
