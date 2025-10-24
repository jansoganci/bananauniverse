//
//  HybridCreditManager.swift
//  BananaUniverse
//
//  Created by AI Assistant on 14.10.2025.
//  Manages daily quota for both anonymous and authenticated users
//

import Foundation
import Supabase
import Combine
import UIKit

/// Manages daily quota for both anonymous and authenticated users
@MainActor
class HybridCreditManager: ObservableObject {
    static let shared = HybridCreditManager()
    
    @Published var userState: UserState = .anonymous(deviceId: UUID().uuidString)
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Daily quota properties
    @Published var dailyQuotaUsed: Int = 0
    @Published var dailyQuotaLimit: Int = 5
    @Published var lastQuotaDate: String = ""
    @Published var isPremiumUser: Bool = false
    
    // Storage keys
    private let deviceUUIDKey = "device_uuid_v1"
    private let userStateKey = "user_state_v1"
    
    // Daily quota storage keys
    private let dailyQuotaKey = "daily_quota_v1"
    private let lastQuotaDateKey = "last_quota_date_v1"
    private let premiumStatusKey = "premium_status_v1"
    
    // Subscription check caching
    private var lastSubscriptionCheck: Date?
    
    private let supabase: SupabaseService
    
    private init() {
        self.supabase = SupabaseService.shared
        loadUserState()
        loadDailyQuota()
        updatePremiumStatus()
        scheduleSubscriptionRefresh()
    }
    
    // MARK: - User State Management
    
    private func loadUserState() {
        if let data = UserDefaults.standard.data(forKey: userStateKey),
           let state = try? JSONDecoder().decode(UserState.self, from: data) {
            userState = state
        } else {
            // First time user - create anonymous state
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
    
    func setUserState(_ newState: UserState) {
        userState = newState
        saveUserState()
        
        // Refresh premium status when user state changes
        Task {
            await refreshPremiumStatus()
        }
    }
    
    // MARK: - New Quota System Integration
    
    /// Check and consume quota using the new backend system
    func checkAndConsumeQuota(isPremium: Bool) async throws -> QuotaInfo {
        print("🆕 [QUOTA] Using new quota system...")
        
        let userState = HybridAuthService.shared.userState
        
        let quotaInfo = try await supabase.consumeQuota(
            userId: userState.isAuthenticated ? userState.identifier : nil,
            deviceId: userState.isAuthenticated ? nil : userState.identifier,
            isPremium: isPremium
        )
        
        // Update local state from backend response
        await updateFromBackendResponse(
            quotaUsed: quotaInfo.quotaUsed,
            quotaLimit: quotaInfo.quotaLimit,
            isPremium: quotaInfo.isPremium
        )
        
        return quotaInfo
    }
    
    /// Main entry point for quota consumption
    func spendCreditWithQuota() async throws -> Bool {
        do {
            let quotaInfo = try await checkAndConsumeQuota(isPremium: isPremiumUser)
            
            // Check if quota is available
            guard quotaInfo.quotaRemaining > 0 || quotaInfo.isPremium else {
                throw QuotaExceededError.dailyLimitReached
            }
            
            // Update local state from backend response
            await updateFromBackendResponse(
                quotaUsed: quotaInfo.quotaUsed,
                quotaLimit: quotaInfo.quotaLimit,
                isPremium: quotaInfo.isPremium
            )
            
            print("✅ [QUOTA] Quota consumed successfully: \(dailyQuotaUsed)/\(dailyQuotaLimit)")
            return true
            
        } catch QuotaExceededError.dailyLimitReached {
            print("❌ [QUOTA] Daily limit reached")
            throw QuotaExceededError.dailyLimitReached
        } catch SupabaseError.quotaExceeded {
            print("❌ [QUOTA] Quota exceeded")
            throw QuotaExceededError.dailyLimitReached
        }
    }
    
    /// Check if user can process image
    func canProcessImage() -> Bool {
        #if DEBUG
        print("🔍 [QUOTA] canProcessImage() - Starting check")
        print("🔍 [QUOTA] isPremiumUser: \(isPremiumUser)")
        #endif
        
        // Premium users bypass all limits
        if isPremiumUser {
            #if DEBUG
            print("✅ [QUOTA] Premium user detected - bypassing all limits")
            #endif
            return true
        }
        
        #if DEBUG
        print("🔍 [QUOTA] Non-premium user - checking quota")
        print("🔍 [QUOTA] Daily quota: \(dailyQuotaUsed)/\(dailyQuotaLimit)")
        #endif
        
        // Check daily quota for non-premium users
        let quotaCheck = dailyQuotaUsed < dailyQuotaLimit
        #if DEBUG
        print("🔍 [QUOTA] Quota check result: \(quotaCheck)")
        #endif
        
        return quotaCheck
    }
    
    // MARK: - Daily Quota Management
    
    private func loadDailyQuota() {
        // Load quota usage from local storage
        dailyQuotaUsed = UserDefaults.standard.integer(forKey: dailyQuotaKey)
        
        // Load last quota date
        lastQuotaDate = UserDefaults.standard.string(forKey: lastQuotaDateKey) ?? ""
        
        // Load premium status
        isPremiumUser = UserDefaults.standard.bool(forKey: premiumStatusKey)
        
        // Check if quota reset is needed
        resetDailyQuotaIfNeeded()
    }
    
    private func saveDailyQuota() {
        UserDefaults.standard.set(dailyQuotaUsed, forKey: dailyQuotaKey)
        UserDefaults.standard.set(lastQuotaDate, forKey: lastQuotaDateKey)
        UserDefaults.standard.set(isPremiumUser, forKey: premiumStatusKey)
    }
    
    private func resetDailyQuotaIfNeeded() {
        let today = getLocalMidnightDate()
        
        if lastQuotaDate != today {
            // Reset quota for new day
            dailyQuotaUsed = 0
            lastQuotaDate = today
            saveDailyQuota()
            #if DEBUG
            print("🔄 [QUOTA] Daily quota reset for new day: \(today)")
            #endif
        }
    }
    
    func incrementDailyQuota() {
        dailyQuotaUsed += 1
        saveDailyQuota()
        #if DEBUG
        print("➕ [QUOTA] Quota incremented: \(dailyQuotaUsed)/\(dailyQuotaLimit)")
        #endif
    }
    
    private func getLocalMidnightDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
    
    // MARK: - Premium User Integration
    
    private func updatePremiumStatus() {
        // Use StoreKit 2 to check subscription status
        Task {
            let hasActiveSubscription = await StoreKitService.shared.hasActiveSubscription()
            if isPremiumUser != hasActiveSubscription {
                isPremiumUser = hasActiveSubscription
                UserDefaults.standard.set(isPremiumUser, forKey: premiumStatusKey)
                saveDailyQuota()
                objectWillChange.send()
                #if DEBUG
                print("🔄 [QUOTA] Premium status updated on init: \(isPremiumUser)")
                #endif
            }
        }
    }
    
    @MainActor
    func refreshPremiumStatus() async {
        // Check if we've already checked subscription status within the last 60 seconds
        if let lastCheck = lastSubscriptionCheck,
           Date().timeIntervalSince(lastCheck) < 60 {
            #if DEBUG
            print("🟡 [QUOTA] Skipping redundant subscription check (cached within 60s)")
            #endif
            return
        }
        lastSubscriptionCheck = Date()
        
        // Use StoreKit 2 to refresh subscription status
        await StoreKitService.shared.updateSubscriptionStatus()
        
        // Update premium status and handle expiration gracefully
        let newPremiumStatus = StoreKitService.shared.isPremiumUser
        if isPremiumUser != newPremiumStatus {
            isPremiumUser = newPremiumStatus
            UserDefaults.standard.set(isPremiumUser, forKey: premiumStatusKey)
            #if DEBUG
            print("🔄 [QUOTA] Premium status changed: \(isPremiumUser)")
            #endif
        }
        
        saveDailyQuota()
        objectWillChange.send()
        #if DEBUG
        print("🔄 [QUOTA] Premium status refreshed after purchase")
        #endif
    }
    
    @MainActor
    func refreshSubscriptionInBackground() async {
        // Check if we've already checked subscription status within the last 60 seconds
        if let lastCheck = lastSubscriptionCheck,
           Date().timeIntervalSince(lastCheck) < 60 {
            #if DEBUG
            print("🟡 [QUOTA] Skipping redundant background subscription check (cached within 60s)")
            #endif
            return
        }
        lastSubscriptionCheck = Date()
        
        do {
            await StoreKitService.shared.updateSubscriptionStatus()
            isPremiumUser = StoreKitService.shared.isPremiumUser
            UserDefaults.standard.set(isPremiumUser, forKey: premiumStatusKey)
            objectWillChange.send()
            #if DEBUG
            print("🔄 [QUOTA] Background subscription refresh completed: \(isPremiumUser)")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ [QUOTA] Background subscription refresh failed: \(error.localizedDescription)")
            #endif
        }
    }
    
    // MARK: - Background Refresh Support
    
    func scheduleSubscriptionRefresh() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await self.refreshSubscriptionInBackground()
            }
        }
    }
    
    // MARK: - Computed Properties for UI
    
    var remainingQuota: Int {
        if isPremiumUser {
            return Int.max  // effectively unlimited
        }
        return max(0, dailyQuotaLimit - dailyQuotaUsed)
    }
    
    var hasQuotaLeft: Bool {
        if isPremiumUser {
            return true  // Premium users always have quota
        }
        return remainingQuota > 0
    }
    
    var quotaDisplayText: String {
        if isPremiumUser {
            return "Unlimited"
        }
        return "\(dailyQuotaUsed)/\(dailyQuotaLimit)"
    }
    
    var isQuotaUnlimited: Bool {
        return isPremiumUser
    }
    
    var shouldShowQuotaWarning: Bool {
        return !isPremiumUser && remainingQuota <= 1
    }
    
    var quotaWarningMessage: String {
        if remainingQuota == 1 {
            return "⚠️ Only 1 generation left today!"
        }
        return ""
    }
    
    // MARK: - New User Initialization
    
    func initializeNewUser() async {
        print("🆕 [QUOTA] Initializing new user...")
        
        // Initialize quota system for new user
        // The backend will create the initial record on first generation
        let userState = HybridAuthService.shared.userState
        
        print("✅ [QUOTA] New user initialized - user state: \(userState)")
        print("🔄 [QUOTA] Quota system ready for first generation")
    }
    
    // MARK: - Quota Loading with Error Handling
    
    func loadQuota() async {
        isLoading = true
        print("🔍 [QUOTA] Loading quota from backend...")
        
        do {
            let userState = HybridAuthService.shared.userState
            
            let result = try await supabase.client
                .rpc("get_quota", params: [
                    "p_user_id": userState.isAuthenticated ? userState.identifier : nil,
                    "p_device_id": userState.isAuthenticated ? nil : userState.identifier
                ])
                .execute()
                .value
            
            // Update quota from backend response
            if let quotaData = result as? [String: Any] {
                dailyQuotaUsed = quotaData["quota_used"] as? Int ?? 0
                dailyQuotaLimit = quotaData["quota_limit"] as? Int ?? 5
            }
            
            print("✅ [QUOTA] Loaded quota: \(dailyQuotaUsed)/\(dailyQuotaLimit)")
            isLoading = false
        } catch {
            print("❌ [QUOTA] Failed to load quota: \(error.localizedDescription)")
            
            // FALLBACK: Use cached values or defaults
            if dailyQuotaUsed == 0 && dailyQuotaLimit == 5 {
                // First time - use defaults
                dailyQuotaUsed = 0
                dailyQuotaLimit = 5
            }
            // Otherwise keep current values
            
            isLoading = false
        }
    }
    
    // MARK: - Device UUID Management
    
    func getDeviceUUID() -> String {
        return getOrCreateDeviceUUID()
    }
    
    private func getOrCreateDeviceUUID() -> String {
        if let existingUUID = UserDefaults.standard.string(forKey: deviceUUIDKey) {
            return existingUUID
        }
        
        let newUUID = UUID().uuidString
        UserDefaults.standard.set(newUUID, forKey: deviceUUIDKey)
        return newUUID
    }
    
    // MARK: - Backend Response Sync
    
    /// Updates local quota state from backend response after image processing
    /// This ensures UI quota counter stays in sync with backend truth
    func updateFromBackendResponse(quotaUsed: Int, quotaLimit: Int, isPremium: Bool) async {
        // Update quota
        self.dailyQuotaUsed = quotaUsed
        self.dailyQuotaLimit = quotaLimit
        
        // Update premium status
        self.isPremiumUser = isPremium
        
        // Persist to local storage
        saveDailyQuota()
        
        #if DEBUG
        print("✅ [QUOTA] Synced from backend: quota=\(quotaUsed)/\(quotaLimit), premium=\(isPremium)")
        #endif
    }
}
