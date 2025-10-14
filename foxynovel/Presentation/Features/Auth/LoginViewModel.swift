//
//  LoginViewModel.swift
//  foxynovel
//
//  Created by Claude on 13/10/25.
//

import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isAuthenticated: Bool = false

    private let loginUseCase: LoginUseCaseProtocol

    init(loginUseCase: LoginUseCaseProtocol) {
        self.loginUseCase = loginUseCase
    }

    convenience init() {
        self.init(loginUseCase: DIContainer.shared.loginUseCase)
    }

    func login() async {
        isLoading = true
        errorMessage = nil

        do {
            let _ = try await loginUseCase.execute(email: email, password: password)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func clearError() {
        errorMessage = nil
    }
}
