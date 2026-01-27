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
//  Removed responsibilities (now in separate services):
//  - Network calls → QuotaService
//  - Cache management → QuotaCache
//  - Error handling → QuotaError/CreditError
//  - Manual JSON decoding → QuotaService
//

import Foundation
import Supabase
import Combine
import UIKit
import StableID

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

    @Published private(set) var creditsTotal: Int = 10 {
        didSet {
            guard oldValue != creditsTotal else { return }
            #if DEBUG
            print("💎 [CREDITS] Lifetime Total: \(oldValue) → \(creditsTotal)")
            #endif
        }
    }

    @Published private(set) var isLoading = true  // Start in loading state until backend confirms
    @Published private(set) var isOffline = false  // Indicates when using cached credits due to offline status

    // MARK: - Private State

    private var observerAdded = false
    private var loadQuotaTask: Task<Void, Never>?
    private var recoveryTime: Date?  // Track when recovery happened to skip loadQuota for a short period

    // Debouncing to prevent rapid successive loads
    private var lastLoadTime: Date?
    private let minimumLoadInterval: TimeInterval = 2.0  // 2 seconds minimum between loads
    private let recoverySkipInterval: TimeInterval = 5.0  // Skip loadQuota for 5 seconds after recovery

    // Legacy user state management (kept for compatibility)
    @Published var userState: UserState = .anonymous(deviceId: UUID().uuidString)
    private let userStateKey = "user_state_v1"
    private let deviceUUIDKey = "device_uuid_v1"

    // MARK: - Initialization

    private init() {
        loadUserState()
        // DON'T load cache on init - wait for backend to confirm real balance
        // This prevents showing stale cached credits on app launch
        scheduleBackgroundRefresh()

        // Migrate old cache if needed (cache still used for background refresh)
        QuotaCache.shared.migrateFromV1IfNeeded()
    }

    // MARK: - Public API

    /// Loads credit balance from backend (idempotent, single-flight)
    func loadQuota() async {
        // Skip if we just recovered from StableID (recovery value is more accurate)
        if let recoveryTime = recoveryTime {
            let timeSinceRecovery = Date().timeIntervalSince(recoveryTime)
            if timeSinceRecovery < recoverySkipInterval {
                #if DEBUG
                print("⏭️ [CREDITS] Skipping load (recently recovered from StableID: \(String(format: "%.1f", timeSinceRecovery))s ago)")
                #endif
                return
            }
        }
        
        // Check network connectivity - if offline, use cached credits
        guard NetworkMonitor.shared.checkConnectivity() else {
            isOffline = true
            #if DEBUG
            print("⚠️ [CREDITS] Offline - using cached balance: \(creditsRemaining)")
            #endif
            return
        }

        // Debouncing: Skip if called too soon after last load
        if let lastLoad = lastLoadTime {
            let timeSinceLastLoad = Date().timeIntervalSince(lastLoad)
            if timeSinceLastLoad < minimumLoadInterval {
                #if DEBUG
                print("⏭️ [CREDITS] Skipping load (too soon after last load: \(String(format: "%.1f", timeSinceLastLoad))s)")
                #endif
                return
            }
        }

        // Cancel any existing task (single-flight)
        loadQuotaTask?.cancel()

        loadQuotaTask = Task {
            // Mark as online since we're making a network request
            isOffline = false
            // Update last load time
            lastLoadTime = Date()

            // Set loading state (removed guard - we want initial load to proceed even if already loading)
            isLoading = true
            defer { isLoading = false }

            let previousBalance = creditsRemaining

            do {
                let userState = HybridAuthService.shared.userState

                #if DEBUG
                if userState.isAuthenticated {
                    print("👤 [CREDITS] Loading for authenticated user: \(userState.identifier)")
                } else {
                    print("📱 [CREDITS] Loading for anonymous device: \(userState.identifier)")
                }
                #endif

                let creditInfo = try await QuotaService.shared.getQuota(
                    userId: userState.isAuthenticated ? userState.identifier : nil,
                    deviceId: userState.isAuthenticated ? nil : userState.identifier
                )

                // Log credit changes for debugging
                #if DEBUG
                if previousBalance != creditInfo.creditsRemaining {
                    print("🔄 [CREDITS] Backend sync: \(previousBalance) → \(creditInfo.creditsRemaining)")
                }
                if let total = creditInfo.creditsTotal {
                    print("💎 [CREDITS] Lifetime total: \(total)")
                }
                if let claimed = creditInfo.initialGrantClaimed {
                    print("🎁 [CREDITS] Initial grant claimed: \(claimed)")
                }
                #endif

                // Update credits (remaining + lifetime total)
                await updateCredits(
                    remaining: creditInfo.creditsRemaining,
                    total: creditInfo.creditsTotal
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
        // Check credit balance
        return creditsRemaining > 0
    }

    /// Initialize new user (loads credits from backend)
    func initializeNewUser() async {
        await loadQuota()
    }

    /// Updates credits from StableID recovery (bypasses normal load flow)
    /// This is called by HybridAuthService after recover_or_init_user RPC
    func updateFromRecovery(credits: Int) async {
        // Save to cache first
        QuotaCache.shared.save(creditsRemaining: credits)
        
        // Update last load time to prevent debouncing from skipping subsequent loads
        lastLoadTime = Date()
        
        // Track recovery time to prevent loadQuota from overwriting recovery value
        recoveryTime = Date()
        
        await MainActor.run {
            self.creditsRemaining = credits
            self.isLoading = false
            
            #if DEBUG
            print("💾 [CREDITS] Recovered from StableID: \(credits) credits")
            #endif
        }
    }

    /// Updates credits from backend response (called by SupabaseService)
    func updateFromBackendResponse(creditsRemaining: Int, isPremium: Bool = false) async {
        // isPremium parameter kept for backward compatibility but ignored
        await updateCredits(remaining: creditsRemaining)
    }

    // Legacy method for backward compatibility
    func updateFromBackendResponse(quotaUsed: Int, quotaLimit: Int, isPremium: Bool = false) async {
        // Convert old quota format to credits, isPremium ignored
        let remaining = max(0, quotaLimit - quotaUsed)
        await updateCredits(remaining: remaining)
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

    /// Background refresh (called when app returns to foreground)
    func refreshCreditsInBackground() async {
        // Refresh credits from backend
        await loadQuota()
    }

    // MARK: - Computed Properties for UI

    var remainingQuota: Int {
        creditsRemaining
    }

    var hasQuotaLeft: Bool {
        creditsRemaining > 0
    }

    var quotaDisplayText: String {
        "\(creditsRemaining) credits"
    }

    var shouldShowQuotaWarning: Bool {
        creditsRemaining <= 1
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
    private func updateCredits(remaining: Int, total: Int? = nil) async {
        // Check if anything changed
        let remainingChanged = creditsRemaining != remaining
        let totalChanged = total != nil && creditsTotal != total!

        guard remainingChanged || totalChanged else {
            #if DEBUG
            print("⏭️ [CREDITS] No changes detected, skipping update")
            #endif
            return
        }

        // Save to cache first (background thread OK)
        QuotaCache.shared.save(creditsRemaining: remaining)

        // Update UI state on main thread
        await MainActor.run {
            if remainingChanged {
                creditsRemaining = remaining
            }
            if let total = total, totalChanged {
                creditsTotal = total
            }
        }
    }

    /// Loads cached credits on init
    private func loadCachedQuota() {
        guard let cached = QuotaCache.shared.load() else {
            #if DEBUG
            let deviceId = getOrCreateDeviceUUID()
            print("📱 [CREDITS] No cached data, using default: 10 credits (device: \(deviceId))")
            #endif
            return
        }

        creditsRemaining = cached.creditsRemaining

        #if DEBUG
        let deviceId = getOrCreateDeviceUUID()
        print("📱 [CREDITS] Loaded from cache: \(cached.creditsRemaining) credits (device: \(deviceId))")
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
        // Get current device ID (source of truth)
        let currentDeviceId = getOrCreateDeviceUUID()

        if let data = UserDefaults.standard.data(forKey: userStateKey),
           let state = try? JSONDecoder().decode(UserState.self, from: data) {

            // Check if device ID needs migration
            if case .anonymous(let cachedDeviceId) = state, cachedDeviceId != currentDeviceId {
                #if DEBUG
                print("🔄 [CREDITS] Device ID migration: \(cachedDeviceId) → \(currentDeviceId)")
                #endif

                // Migrate to current device ID
                userState = .anonymous(deviceId: currentDeviceId)
                saveUserState()
            } else {
                userState = state
            }
        } else {
            // No cached state, create new with current device ID
            userState = .anonymous(deviceId: currentDeviceId)
            saveUserState()
        }
    }

    private func saveUserState() {
        if let data = try? JSONEncoder().encode(userState) {
            UserDefaults.standard.set(data, forKey: userStateKey)
        }
    }

    private func getOrCreateDeviceUUID() -> String {
        // StableID is already configured in BananaUniverseApp.init()
        // Migration from UserDefaults happens there before StableID.configure()
        #if DEBUG
        print("🔐 [CreditManager] Using StableID: \(StableID.id)")
        #endif

        return StableID.id
    }
}
