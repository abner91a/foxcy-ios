//
//  NotificationEndpoints.swift
//  foxynovel
//
//  Created by Claude on 20/10/25.
//

import Foundation

enum NotificationEndpoints: Endpoint {
    case registerDeviceToken(
        token: String,
        platform: String,
        tokenType: String,
        appVersion: String?,
        deviceInfo: RegisterDeviceTokenRequestDTO.DeviceInfo?
    )

    var path: String {
        switch self {
        case .registerDeviceToken:
            return "/v1/device-tokens/register"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .registerDeviceToken:
            return .post
        }
    }

    var body: Encodable? {
        switch self {
        case .registerDeviceToken(let token, let platform, let tokenType, let appVersion, let deviceInfo):
            return RegisterDeviceTokenRequestDTO(
                token: token,
                platform: platform,
                tokenType: tokenType,
                appVersion: appVersion,
                deviceInfo: deviceInfo
            )
        }
    }
}
