//
//  foxynovelApp.swift
//  foxynovel
//
//  Created by Abner on 13/10/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseMessaging
import GoogleSignIn
import UserNotifications

@main
struct foxynovelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onOpenURL { url in
                    // Handle Google Sign-In callback URL
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(DIContainer.shared.modelContainer)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        print("🔥 Firebase configured successfully")

        // Configure notification delegates
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // Request notification permissions
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("⚠️ Error requesting notification permission: \(error.localizedDescription)")
                return
            }
            print("📱 Push notification permission: \(granted ? "granted" : "denied")")
        }

        // Register for remote notifications (will fail silently on simulator)
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: - APNS Token Handling

    /// Called when APNS token is successfully obtained (only on real devices)
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Configure Firebase with APNS token
        Messaging.messaging().apnsToken = deviceToken

        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("✅ APNS token registered: \(token.prefix(20))...")
    }

    /// Called when APNS registration fails (expected on simulator)
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if targetEnvironment(simulator)
        print("ℹ️ APNS registration skipped (simulators don't support push notifications)")
        #else
        print("⚠️ APNS registration failed: \(error.localizedDescription)")
        #endif
    }

    // MARK: - FCM Token Handling

    /// Called when FCM token is received or refreshed
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("ℹ️ FCM token not available yet")
            return
        }

        print("✅ FCM token received: \(fcmToken.prefix(20))...")

        // Store token in UserDefaults for later use
        UserDefaults.standard.set(fcmToken, forKey: "fcmToken")

        // TODO: If user is already authenticated, send token to backend automatically
        // This could be done by posting a notification that ProfileViewModel listens to
    }

    // MARK: - Notification Handling (when app is in foreground)

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("📬 Notification received while app in foreground: \(userInfo)")

        // Show notification even when app is in foreground
        completionHandler([[.banner, .sound, .badge]])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📬 User tapped notification: \(userInfo)")

        // Handle notification tap here (e.g., navigate to specific screen)

        completionHandler()
    }
}
