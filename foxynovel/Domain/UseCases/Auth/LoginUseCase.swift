//
//  LoginUseCase.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation

protocol LoginUseCaseProtocol {
    func execute(email: String, password: String) async throws -> AuthResponse
}

final class LoginUseCase: LoginUseCaseProtocol {
    private let repository: AuthRepositoryProtocol

    init(repository: AuthRepositoryProtocol) {
        self.repository = repository
    }

    func execute(email: String, password: String) async throws -> AuthResponse {
        // Validate input
        guard !email.isBlank else {
            throw ValidationError.emptyEmail
        }

        guard email.isValidEmail else {
            throw ValidationError.invalidEmail
        }

        guard !password.isBlank else {
            throw ValidationError.emptyPassword
        }

        guard password.isValidPassword else {
            throw ValidationError.invalidPassword
        }

        return try await repository.login(email: email, password: password)
    }
}

enum ValidationError: LocalizedError {
    case emptyEmail
    case invalidEmail
    case emptyPassword
    case invalidPassword
    case emptyUsername

    var errorDescription: String? {
        switch self {
        case .emptyEmail:
            return "El email no puede estar vacío"
        case .invalidEmail:
            return "El formato del email no es válido"
        case .emptyPassword:
            return "La contraseña no puede estar vacía"
        case .invalidPassword:
            return "La contraseña debe tener al menos 6 caracteres"
        case .emptyUsername:
            return "El nombre de usuario no puede estar vacío"
        }
    }
}
