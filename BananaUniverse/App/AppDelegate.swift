//
//  AppDelegate.swift
//  BananaUniverse
//
//  Created by AI Assistant on December 2024.
//  Handles app lifecycle events for background credit refresh
//

import UIKit
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if DEBUG
        print("🚀 App launched - setting up background credit refresh")
        #endif
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        #if DEBUG
        print("🔄 App became active - triggering background credit refresh")
        #endif
        
        Task { @MainActor in
            await CreditManager.shared.refreshCreditsInBackground()
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        #if DEBUG
        print("⏸️ App will resign active")
        #endif
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        #if DEBUG
        print("📱 App entered background")
        #endif
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        #if DEBUG
        print("🔄 App will enter foreground - credit refresh will be triggered")
        #endif
    }
}
