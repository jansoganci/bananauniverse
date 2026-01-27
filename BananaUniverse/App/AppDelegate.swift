//
//  AppDelegate.swift
//  BananaUniverse
//
//  Created by AI Assistant on December 2024.
//  Handles app lifecycle events for background credit refresh
//

import UIKit
import SwiftUI
import Kingfisher

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if DEBUG
        print("🚀 App launched - setting up background credit refresh")
        #endif
        
        // Phase 2: Configure Kingfisher Global Cache
        configureKingfisher()
        
        return true
    }
    
    // MARK: - Kingfisher Configuration
    
    private func configureKingfisher() {
        let cache = ImageCache.default
        
        // Memory Cache: 100MB
        cache.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024
        
        // Disk Cache: 500MB
        cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024
        
        // Expiration: 7 Days
        cache.diskStorage.config.expiration = .days(7)
        
        // Default Options
        KingfisherManager.shared.defaultOptions = [
            .scaleFactor(UIScreen.main.scale),
            .transition(.fade(0.25)),
            .cacheSerializer(FormatIndicatedCacheSerializer.png),
            .diskCacheExpiration(.days(7))
        ]
        
        #if DEBUG
        print("🖼️ Kingfisher configured: 100MB RAM, 500MB Disk, 7 days expiration")
        #endif
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
