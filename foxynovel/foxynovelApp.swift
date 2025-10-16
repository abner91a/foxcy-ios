//
//  foxynovelApp.swift
//  foxynovel
//
//  Created by Abner on 13/10/25.
//

import SwiftUI
import SwiftData

@main
struct foxynovelApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(DIContainer.shared.modelContainer)
    }
}
