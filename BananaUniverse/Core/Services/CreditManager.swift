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

    @Published private(set) var isLoading = false

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
                await updateCredits(remaining: creditInfo.creditsRemaining)

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
    private func updateCredits(remaining: Int) async {
        // Only update if values actually changed
        guard creditsRemaining != remaining else {
            #if DEBUG
            print("⏭️ [CREDITS] No changes detected, skipping update")
            #endif
            return
        }

        // Save to cache first (background thread OK)
        QuotaCache.shared.save(creditsRemaining: remaining)

        // Update UI state on main thread
        await MainActor.run {
            creditsRemaining = remaining
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

        #if DEBUG
        print("📱 [CREDITS] Loaded from cache: \(cached.creditsRemaining) credits")
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
