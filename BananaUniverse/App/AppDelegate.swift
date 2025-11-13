//
//  AppDelegate.swift
//  BananaUniverse
//
//  Created by AI Assistant on December 2024.
//  Handles app lifecycle events for background subscription refresh
//

import UIKit
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if DEBUG
        print("🚀 App launched - setting up background subscription refresh")
        #endif
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        #if DEBUG
        print("🔄 App became active - triggering background subscription refresh")
        #endif
        
        Task { @MainActor in
            await CreditManager.shared.refreshSubscriptionInBackground()
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
        print("🔄 App will enter foreground - subscription refresh will be triggered")
        #endif
    }
}
