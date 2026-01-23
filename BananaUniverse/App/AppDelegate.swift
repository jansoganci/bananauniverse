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
        
        // Configure URLCache for image caching
        let cacheSizeMemory = 50 * 1024 * 1024 // 50MB memory cache
        let cacheSizeDisk = 200 * 1024 * 1024   // 200MB disk cache
        let cache = URLCache(
            memoryCapacity: cacheSizeMemory,
            diskCapacity: cacheSizeDisk,
            diskPath: "imageCache"
        )
        URLCache.shared = cache
        
        #if DEBUG
        print("💾 URLCache configured: \(cacheSizeMemory / 1024 / 1024)MB memory, \(cacheSizeDisk / 1024 / 1024)MB disk")
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
