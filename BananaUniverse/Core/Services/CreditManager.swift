//
//  CreditManager.swift
//  BananaUniverse
//
//  Created by Refactor on November 4, 2025.
//  Updated: November 13, 2025 - Converted to persistent credit system
//  Simplified orchestrator for credit state management
//
//  RESPONSIBILITIES (Single Purpose):
//  - Orchestrates QuotaService (network) + QuotaCache (storage)
//  - Manages @Published UI state
//  - Provides computed properties for UI consumption
//
//  REMOVED RESPONSIBILITIES (Now in separate services):
//  ❌ Network calls → QuotaService
//  ❌ Cache management → QuotaCache
//  ❌ Error handling → QuotaError/CreditError
//  ❌ Manual JSON decoding → QuotaService
//

import Foundation
import Supabase
import Combine
import UIKit

/// Orchestrates credit state between network, cache, and UI
@MainActor
class CreditManager: ObservableObject {
    static let shared = CreditManager()

    // MARK: - Published State (UI Layer Only)

    @Published private(set) var creditsRemaining: Int = 10 {
        didSet {
            guard oldValue != creditsRemaining else { return }
            #if DEBUG
            print("📊 [CREDITS] Balance: \(oldValue) → \(creditsRemaining)")
            #endif
        }
    }

    @Published private(set) var isPremiumUser: Bool = false {
        didSet {
            guard oldValue != isPremiumUser else { return }
            #if DEBUG
            print("🔄 [PREMIUM] Status changed: \(oldValue) → \(isPremiumUser)")
            #endif
        }
    }

    @Published private(set) var isLoading = false

    // MARK: - Legacy Properties (For Backward Compatibility)
    // These allow existing code to continue working during transition

    var dailyQuotaUsed: Int {
        // In credit system, we don't track "used"
        // Return 0 for now to maintain compatibility
        return isPremiumUser ? 0 : max(0, 10 - creditsRemaining)
    }

    var dailyQuotaLimit: Int {
        // Premium users have unlimited, free users start with 10
        return isPremiumUser ? 999999 : 10
    }

    // MARK: - Private State

    private var observerAdded = false
    private var loadQuotaTask: Task<Void, Never>?

    // Legacy user state management (kept for compatibility)
    @Published var userState: UserState = .anonymous(deviceId: UUID().uuidString)
    private let userStateKey = "user_state_v1"
    private let deviceUUIDKey = "device_uuid_v1"

    // MARK: - Initialization

    private init() {
        loadUserState()
        loadCachedQuota()
        scheduleBackgroundRefresh()

        // Migrate old cache if needed
        QuotaCache.shared.migrateFromV1IfNeeded()
    }

    // MARK: - Public API

    /// Loads credit balance from backend (idempotent, single-flight)
    func loadQuota() async {
        // Cancel any existing task (single-flight)
        loadQuotaTask?.cancel()

        loadQuotaTask = Task {
            // Prevent concurrent calls
            guard !isLoading else { return }
            isLoading = true
            defer { isLoading = false }

            do {
                let userState = HybridAuthService.shared.userState
                let creditInfo = try await QuotaService.shared.getQuota(
                    userId: userState.isAuthenticated ? userState.identifier : nil,
                    deviceId: userState.isAuthenticated ? nil : userState.identifier
                )

                // Only update if values changed
                await updateCredits(
                    remaining: creditInfo.creditsRemaining,
                    premium: creditInfo.isPremium
                )

            } catch let error as QuotaError {
                print("❌ [CREDITS] Load failed: \(error.displayMessage)")
                // Keep cached values on error
            } catch {
                print("❌ [CREDITS] Unexpected error: \(error.localizedDescription)")
            }
        }

        await loadQuotaTask?.value
    }

    /// Check if user can process image (synchronous, uses cached state)
    func canProcessImage() -> Bool {
        // Premium users bypass all limits
        if isPremiumUser {
            return true
        }

        // Check credit balance for non-premium users
        return creditsRemaining > 0
    }

    /// Initialize new user (loads credits from backend)
    func initializeNewUser() async {
        await loadQuota()
    }

    /// Updates credits from backend response (called by SupabaseService)
    func updateFromBackendResponse(creditsRemaining: Int, isPremium: Bool) async {
        await updateCredits(remaining: creditsRemaining, premium: isPremium)
    }

    // Legacy method for backward compatibility
    func updateFromBackendResponse(quotaUsed: Int, quotaLimit: Int, isPremium: Bool) async {
        // Convert old quota format to credits
        let remaining = max(0, quotaLimit - quotaUsed)
        await updateCredits(remaining: remaining, premium: isPremium)
    }

    // MARK: - User State Management (Legacy)

    func setUserState(_ newState: UserState) {
        userState = newState
        saveUserState()

        // Refresh credits when user state changes
        Task {
            await loadQuota()
        }
    }

    func getDeviceUUID() -> String {
        return getOrCreateDeviceUUID()
    }

    // MARK: - Premium Status Integration

    /// Refreshes premium status from StoreKit
    func refreshPremiumStatus() async {
        await StoreKitService.shared.updateSubscriptionStatus()
        let newPremiumStatus = StoreKitService.shared.isPremiumUser

        // Only update if changed
        if isPremiumUser != newPremiumStatus {
            isPremiumUser = newPremiumStatus
            QuotaCache.shared.save(creditsRemaining: creditsRemaining, premium: isPremiumUser)
        }
    }

    /// Background refresh (called when app returns to foreground)
    func refreshSubscriptionInBackground() async {
        await StoreKitService.shared.updateSubscriptionStatus()
        let newPremiumStatus = StoreKitService.shared.isPremiumUser

        if isPremiumUser != newPremiumStatus {
            isPremiumUser = newPremiumStatus
            QuotaCache.shared.save(creditsRemaining: creditsRemaining, premium: isPremiumUser)
        }

        // Also refresh credits from backend
        await loadQuota()
    }

    // MARK: - Computed Properties for UI

    var remainingQuota: Int {
        isPremiumUser ? Int.max : creditsRemaining
    }

    var hasQuotaLeft: Bool {
        isPremiumUser || creditsRemaining > 0
    }

    var quotaDisplayText: String {
        isPremiumUser ? "Unlimited" : "\(creditsRemaining) credits"
    }

    var isQuotaUnlimited: Bool {
        isPremiumUser
    }

    var shouldShowQuotaWarning: Bool {
        !isPremiumUser && creditsRemaining <= 1
    }

    var quotaWarningMessage: String {
        if creditsRemaining == 1 {
            return "⚠️ Only 1 credit left!"
        } else if creditsRemaining == 0 {
            return "⚠️ No credits remaining!"
        }
        return ""
    }

    // MARK: - Private Helpers

    /// Updates credit state (atomic, with change detection)
    private func updateCredits(remaining: Int, premium: Bool) async {
        // Only update if values actually changed
        guard creditsRemaining != remaining ||
              isPremiumUser != premium else {
            #if DEBUG
            print("⏭️ [CREDITS] No changes detected, skipping update")
            #endif
            return
        }

        // Save to cache first (background thread OK)
        QuotaCache.shared.save(creditsRemaining: remaining, premium: premium)

        // Update UI state on main thread
        await MainActor.run {
            creditsRemaining = remaining
            isPremiumUser = premium
        }
    }

    /// Loads cached credits on init
    private func loadCachedQuota() {
        guard let cached = QuotaCache.shared.load() else {
            #if DEBUG
            print("📱 [CREDITS] No cached data, using default: 10 credits")
            #endif
            return
        }

        creditsRemaining = cached.creditsRemaining
        isPremiumUser = cached.premium

        #if DEBUG
        print("📱 [CREDITS] Loaded from cache: \(cached.creditsRemaining) credits, premium: \(cached.premium)")
        #endif
    }

    /// Schedules background refresh on app foreground (once only)
    private func scheduleBackgroundRefresh() {
        // Prevent duplicate observer registration
        guard !observerAdded else { return }
        observerAdded = true

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadQuota()
            }
        }

        #if DEBUG
        print("🔔 [CREDITS] Background refresh observer registered")
        #endif
    }

    // MARK: - User State (Legacy)

    private func loadUserState() {
        if let data = UserDefaults.standard.data(forKey: userStateKey),
           let state = try? JSONDecoder().decode(UserState.self, from: data) {
            userState = state
        } else {
            let deviceId = getOrCreateDeviceUUID()
            userState = .anonymous(deviceId: deviceId)
            saveUserState()
        }
    }

    private func saveUserState() {
        if let data = try? JSONEncoder().encode(userState) {
            UserDefaults.standard.set(data, forKey: userStateKey)
        }
    }

    private func getOrCreateDeviceUUID() -> String {
        if let existingUUID = UserDefaults.standard.string(forKey: deviceUUIDKey) {
            return existingUUID
        }

        let newUUID = UUID().uuidString
        UserDefaults.standard.set(newUUID, forKey: deviceUUIDKey)
        return newUUID
    }
}
