//
//  Notification+Extensions.swift
//  foxynovel
//
//  Created by Claude on 21/10/25.
//

import Foundation

extension Notification.Name {
    /// Posted when authentication state changes (login/logout)
    static let authenticationDidChange = Notification.Name("authenticationDidChange")

    /// Posted when session expires and automatic refresh fails
    /// Triggers automatic logout and user notification
    static let sessionExpired = Notification.Name("sessionExpired")

    /// Posted when token refresh fails (for analytics/logging)
    static let tokenRefreshFailed = Notification.Name("tokenRefreshFailed")
}
