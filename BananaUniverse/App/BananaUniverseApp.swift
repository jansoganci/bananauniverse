//
//  BananaUniverseApp.swift
//  BananaUniverse
//
//  Created by AI Assistant on 14.10.2025.
//

import SwiftUI

@main
struct BananaUniverseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        Task {
            // Mock Adapty activation - always succeeds
            #if DEBUG
            print("Mock: Adapty activated successfully")
            #endif
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // CRITICAL: Initialize quota system on app launch
                    await HybridCreditManager.shared.initializeNewUser()
                }
        }
    }
}
