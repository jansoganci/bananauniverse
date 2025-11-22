//
//  BananaUniverseApp.swift
//  BananaUniverse
//
//  Created by AI Assistant on 14.10.2025.
//

import SwiftUI
import StableID
import StoreKit

@main
struct BananaUniverseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasInitialized = false  // Prevent race between .task and .onChange

    // MARK: - Onboarding State
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @State private var showOnboarding = false

    init() {
        // CRITICAL: Initialize StableID SYNCHRONOUSLY to prevent race conditions
        // Services (CreditManager, HybridAuthService) may access StableID.id immediately
        // Async configuration would cause fatalError("StableID not configured") crash
        configureStableIDSynchronously()
    }

    /// Synchronous StableID configuration to prevent race condition crashes
    /// Pattern from StableID README: configure immediately, then fetch App Transaction ID in background
    private func configureStableIDSynchronously() {
        #if DEBUG
        print("🔐 [StableID] Configuring device ID persistence...")
        #endif

        // MIGRATION: Check for legacy UserDefaults device ID before configuring StableID
        // This must happen BEFORE StableID.configure() because configure() can only be called once
        if let legacyUUID = UserDefaults.standard.string(forKey: Config.legacyDeviceIDKey) {
            #if DEBUG
            print("🔄 [StableID] Migrating legacy device ID from UserDefaults: \(legacyUUID)")
            #endif

            // Configure StableID with legacy UUID using .preferStored policy
            // This ensures the legacy ID is preserved and synced to iCloud
            StableID.configure(id: legacyUUID, policy: .preferStored)

            // Remove from UserDefaults after migration (now stored in iCloud)
            UserDefaults.standard.removeObject(forKey: Config.legacyDeviceIDKey)

            #if DEBUG
            print("✅ [StableID] Migrated to StableID: \(StableID.id)")
            #endif
        }
        // Check if we have a stored ID (from iCloud or local storage)
        else if StableID.hasStoredID {
            // Fast path: Stored ID exists, configure synchronously
            StableID.configure()

            #if DEBUG
            print("🔐 [StableID] Configured with stored ID: \(StableID.id)")
            #endif
        } else {
            // No stored ID: Configure with generated UUID immediately (synchronous)
            // This ensures StableID.id is immediately available to prevent crashes
            StableID.configure()

            #if DEBUG
            print("🔐 [StableID] Configured with generated ID: \(StableID.id)")
            #endif
        }

        // Try to fetch App Transaction ID in background and update if available
        if #available(iOS 16.0, *) {
            Task {
                do {
                    // Use StableID's built-in method (not custom string composition)
                    let appTransactionID = try await StableID.fetchAppTransactionID()

                    // Validate App Transaction ID before updating
                    // Simulator and some error cases may return "0" or empty string
                    if !appTransactionID.isEmpty && appTransactionID != "0" {
                        // Update to use App Transaction ID (most secure identifier)
                        StableID.identify(id: appTransactionID)

                        #if DEBUG
                        print("🔐 [StableID] Updated to App Transaction ID: \(appTransactionID)")
                        #endif
                    } else {
                        #if DEBUG
                        print("⚠️ [StableID] Invalid App Transaction ID received: '\(appTransactionID)', keeping current ID: \(StableID.id)")
                        #endif
                        // Skip update, keep current StableID
                    }
                } catch {
                    #if DEBUG
                    print("⚠️ [StableID] Could not fetch App Transaction ID: \(error.localizedDescription)")
                    print("🔐 [StableID] Continuing with current ID: \(StableID.id)")
                    #endif
                }
            }
        } else {
            #if DEBUG
            print("🔐 [StableID] iOS < 16, App Transaction ID not available")
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // CRITICAL: Initialize quota system on app launch (only once)
                    guard !hasInitialized else {
                        #if DEBUG
                        print("⏭️ [App] Skipping initialization (already initialized)")
                        #endif
                        return
                    }

                    hasInitialized = true

                    #if DEBUG
                    print("🚀 [App] Initializing credits on app launch")
                    #endif

                    await CreditManager.shared.initializeNewUser()

                    // Check if user needs onboarding after initialization
                    if !hasSeenOnboarding {
                        #if DEBUG
                        print("👋 [App] First launch detected, showing onboarding")
                        #endif

                        // Small delay to let app fully load
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        showOnboarding = true
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    // Refresh credits when app comes to foreground (after initialization)
                    if newPhase == .active && hasInitialized {
                        #if DEBUG
                        print("🔄 [App] App became active, refreshing credits")
                        #endif

                        Task {
                            await CreditManager.shared.loadQuota()
                        }
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(onComplete: {
                        #if DEBUG
                        print("✅ [App] Onboarding dismissed")
                        #endif
                        showOnboarding = false
                    })
                }
        }
    }
}
