//
//  HybridCreditManager.swift
//  noname_banana
//
//  Created by AI Assistant on 14.10.2025.
//

import Foundation
import Supabase
import Combine
import UIKit
// import Adapty

/// Manages credits for both anonymous and authenticated users
@MainActor
class HybridCreditManager: ObservableObject {
    static let shared = HybridCreditManager()
    
    @Published var credits: Int = 0
    @Published var userState: UserState = .anonymous(deviceId: UUID().uuidString)
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var creditsLoaded = false // Track if credits have been loaded from backend
    
    // Daily quota properties
    @Published var dailyQuotaUsed: Int = 0
    @Published var dailyQuotaLimit: Int = 5
    @Published var lastQuotaDate: String = ""
    @Published var isPremiumUser: Bool = false
    
    // Credit costs
    private let FREE_CREDITS = 10
    private let CREDIT_COST_PER_PROCESS = 1
    
    // Storage keys
    private let creditsKey = "hybrid_credits_v1"
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
        loadCredits()
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
        loadCredits()
        
        // Refresh premium status when user state changes
        Task {
            await refreshPremiumStatus()
        }
    }
    
    // MARK: - Credit Management
    
    func loadCredits() {
        creditsLoaded = false
        switch userState {
        case .anonymous(let deviceId):
            Task {
                do {
                    await loadAnonymousCredits(deviceId: deviceId)
                    await MainActor.run {
                        creditsLoaded = true
                        #if DEBUG
                        print("✅ Anonymous credits loaded successfully: \(credits)")
                        #endif
                    }
                } catch {
                    await MainActor.run {
                        creditsLoaded = true // Still mark as loaded to prevent infinite loading state
                        #if DEBUG
                        print("❌ Failed to load anonymous credits: \(error.localizedDescription)")
                        #endif
                    }
                }
            }
        case .authenticated(let user):
            Task {
                do {
                    await loadAuthenticatedCredits(userId: user.id)
                    await MainActor.run {
                        creditsLoaded = true
                        #if DEBUG
                        print("✅ Authenticated credits loaded successfully: \(credits)")
                        #endif
                    }
                } catch {
                    await MainActor.run {
                        creditsLoaded = true // Still mark as loaded to prevent infinite loading state
                        #if DEBUG
                        print("❌ Failed to load authenticated credits: \(error.localizedDescription)")
                        #endif
                    }
                }
            }
        }
    }
    
    func hasCredits() -> Bool {
        return credits > 0
    }
    
    func canProcessImage() -> Bool {
        #if DEBUG
        print("🔍 canProcessImage() - Starting check")
        print("🔍 isPremiumUser: \(isPremiumUser)")
        #endif
        
        // Check premium status FIRST - premium users bypass all limits
        if isPremiumUser {
            #if DEBUG
            print("✅ Premium user detected - bypassing all limits")
            #endif
            return true
        }
        
        #if DEBUG
        print("🔍 Non-premium user - checking credits and quota")
        print("🔍 Credits: \(credits), Daily quota: \(dailyQuotaUsed)/\(dailyQuotaLimit)")
        #endif
        
        // Check credits for non-premium users
        guard credits > 0 else { 
            #if DEBUG
            print("❌ Insufficient credits: \(credits)")
            #endif
            return false 
        }
        
        // Check daily quota for non-premium users
        let quotaCheck = dailyQuotaUsed < dailyQuotaLimit
        #if DEBUG
        print("🔍 Quota check result: \(quotaCheck)")
        #endif
        
        return quotaCheck
    }
    
    func spendCredit() async throws -> Bool {
        guard credits > 0 else {
            throw HybridCreditError.insufficientCredits
        }
        
        credits -= CREDIT_COST_PER_PROCESS
        
        switch userState {
        case .anonymous(let deviceId):
            saveAnonymousCredits(deviceId: deviceId)
        case .authenticated(let user):
            try await saveAuthenticatedCredits(userId: user.id)
        }
        
        return true
    }
    
    func spendCreditWithQuota() async throws -> Bool {
        // Check if user can process (includes quota check)
        guard canProcessImage() else {
            throw HybridCreditError.insufficientCredits
        }
        
        // Spend credit
        try await spendCredit()
        
        // Update quota for non-premium users
        if !isPremiumUser {
            incrementDailyQuota()
        }
        
        return true
    }
    
    func addCredits(_ amount: Int, source: CreditSource) async throws {
        credits += amount
        
        switch userState {
        case .anonymous(let deviceId):
            saveAnonymousCredits(deviceId: deviceId)
        case .authenticated(let user):
            try await saveAuthenticatedCredits(userId: user.id)
        }
        
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
            
        }
    }
    
    private func incrementDailyQuota() {
        dailyQuotaUsed += 1
        saveDailyQuota()
        
    }
    
    private func getLocalMidnightDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
    
    private func isQuotaResetNeeded() -> Bool {
        let today = getLocalMidnightDate()
        return lastQuotaDate != today
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
                print("🔄 Premium status updated on init: \(isPremiumUser)")
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
            print("🟡 Skipping redundant subscription check (cached within 60s)")
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
            print("🔄 Premium status changed: \(isPremiumUser)")
            #endif
        }
        
        saveDailyQuota()
        objectWillChange.send()
        #if DEBUG
        print("🔄 Premium status refreshed after purchase")
        #endif
    }
    
    @MainActor
    func refreshSubscriptionInBackground() async {
        // Check if we've already checked subscription status within the last 60 seconds
        if let lastCheck = lastSubscriptionCheck,
           Date().timeIntervalSince(lastCheck) < 60 {
            #if DEBUG
            print("🟡 Skipping redundant background subscription check (cached within 60s)")
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
            print("🔄 Background subscription refresh completed: \(isPremiumUser)")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ Background subscription refresh failed: \(error.localizedDescription)")
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
    
    // MARK: - Anonymous User Credits
    
    private func loadAnonymousCredits(deviceId: String) async {
        do {
            let result: [AnonymousCredits] = try await supabase.client
                .from("anonymous_credits")
                .select()
                .eq("device_id", value: deviceId)
                .execute()
                .value
            
            if let anonymousCredits = result.first {
                credits = anonymousCredits.credits
                #if DEBUG
                print("✅ Loaded anonymous credits from backend: \(credits)")
                #endif
            } else {
                // No backend record - check local storage
                let localCredits = getLocalCredits(deviceId: deviceId)
                if localCredits > 0 {
                    // Attempt to migrate local credits to backend
                    try? await createAnonymousCreditsRecord(deviceId: deviceId, initialCredits: localCredits)
                    credits = localCredits
                    #if DEBUG
                    print("✅ Using local credits (backend will sync on first Generate): \(credits)")
                    #endif
                } else {
                    // New user - give free credits locally
                    credits = FREE_CREDITS
                    saveLocalCredits(deviceId: deviceId)
                    // Attempt to create backend record (will auto-create on first Generate if this fails)
                    try? await createAnonymousCreditsRecord(deviceId: deviceId, initialCredits: FREE_CREDITS)
                    #if DEBUG
                    print("✅ New user - starting with \(credits) free credits")
                    print("⚠️ Backend record will be auto-created on first Generate")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("⚠️ Failed to load anonymous credits from backend: \(error.localizedDescription)")
            #endif
            // Fallback to local storage
            credits = getLocalCredits(deviceId: deviceId)
            if credits == 0 {
                credits = FREE_CREDITS
                saveLocalCredits(deviceId: deviceId)
            }
            #if DEBUG
            print("✅ Fallback to local credits: \(credits)")
            print("⚠️ Backend will sync on first Generate")
            #endif
        }
    }
    
    private func saveAnonymousCredits(deviceId: String) {
        // Save locally first
        saveLocalCredits(deviceId: deviceId)
        
        // Then sync to backend
        Task {
            do {
                try await updateAnonymousCreditsBackend(deviceId: deviceId)
            } catch {
            }
        }
    }
    
    private func createAnonymousCreditsRecord(deviceId: String, initialCredits: Int) async throws {
        let anonymousCredits = AnonymousCredits(
            deviceId: deviceId,
            credits: initialCredits,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        do {
            try await supabase.client
                .from("anonymous_credits")
                .insert(anonymousCredits)
                .execute()
            
            #if DEBUG
            print("✅ Created anonymous credits record in backend for device: \(deviceId)")
            print("✅ Initial credits: \(initialCredits)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to create anonymous credits record for device: \(deviceId)")
            print("❌ Error: \(error.localizedDescription)")
            print("⚠️ This is normal for new users - backend will auto-create on first Generate")
            #endif
            // Don't throw - let backend self-heal on first image generation
            // throw error
        }
    }
    
    private func updateAnonymousCreditsBackend(deviceId: String) async throws {
        try await supabase.client
            .from("anonymous_credits")
            .update(["credits": String(credits), "updated_at": Date().ISO8601Format()])
            .eq("device_id", value: deviceId)
            .execute()
        
    }
    
    // MARK: - Authenticated User Credits
    
    private func loadAuthenticatedCredits(userId: UUID) async {
        do {
            let result: [UserCredits] = try await supabase.client
                .from("user_credits")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            
            if let userCredits = result.first {
                credits = userCredits.credits
                #if DEBUG
                print("✅ Loaded authenticated credits from backend: \(credits)")
                #endif
            } else {
                // New authenticated user - check local credits for migration
                let localCredits = getLocalCredits(deviceId: userState.identifier)
                let initialCredits = max(localCredits, FREE_CREDITS)
                credits = initialCredits
                saveLocalCredits(deviceId: userState.identifier)
                
                // Attempt to create backend record (will auto-create on first Generate if this fails)
                try? await createAuthenticatedCreditsRecord(userId: userId)
                #if DEBUG
                print("✅ New authenticated user - starting with \(credits) credits")
                print("⚠️ Backend record will be auto-created on first Generate")
                #endif
            }
        } catch {
            #if DEBUG
            print("⚠️ Failed to load authenticated credits from backend: \(error.localizedDescription)")
            #endif
            // Fallback to local storage
            let localCredits = getLocalCredits(deviceId: userState.identifier)
            credits = localCredits > 0 ? localCredits : FREE_CREDITS
            if credits > 0 {
                saveLocalCredits(deviceId: userState.identifier)
            }
            #if DEBUG
            print("✅ Fallback to local credits: \(credits)")
            print("⚠️ Backend will sync on first Generate")
            #endif
        }
    }
    
    private func saveAuthenticatedCredits(userId: UUID) async throws {
        try await supabase.client
            .from("user_credits")
            .upsert([
                "user_id": userId.uuidString,
                "credits": String(credits),
                "updated_at": Date().ISO8601Format()
            ])
            .execute()
        
    }
    
    private func createAuthenticatedCreditsRecord(userId: UUID) async throws {
        // Check if user has local credits to migrate
        let localCredits = getLocalCredits(deviceId: userState.identifier)
        let initialCredits = max(localCredits, FREE_CREDITS)
        
        do {
            try await supabase.client
                .from("user_credits")
                .insert([
                    "user_id": userId.uuidString,
                    "credits": String(initialCredits),
                    "created_at": Date().ISO8601Format(),
                    "updated_at": Date().ISO8601Format()
                ])
                .execute()
            
            credits = initialCredits
            
            #if DEBUG
            print("✅ Created authenticated credits record in backend with \(initialCredits) credits")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to create authenticated credits record: \(error.localizedDescription)")
            print("⚠️ This is normal for new users - backend will auto-create on first Generate")
            #endif
            // Don't throw - let backend self-heal on first image generation
            // throw error
        }
    }
    
    // MARK: - Migration (Anonymous → Authenticated)
    
    func migrateToAuthenticated(user: User) async throws {
        guard case .anonymous(let deviceId) = userState else {
            throw HybridCreditError.alreadyAuthenticated
        }
        
        let localCredits = getLocalCredits(deviceId: deviceId)
        
        
        // Update user state
        userState = .authenticated(user: user)
        saveUserState()
        
        // Load authenticated credits (will create new record)
        await loadAuthenticatedCredits(userId: user.id)
        
        // Add migrated credits
        if localCredits > 0 {
            try await addCredits(localCredits, source: .migration)
        }
        
        // Clear local anonymous credits
        clearLocalCredits(deviceId: deviceId)
        
    }
    
    // MARK: - Local Storage Helpers
    
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
    
    private func getLocalCredits(deviceId: String) -> Int {
        return UserDefaults.standard.integer(forKey: "\(creditsKey)_\(deviceId)")
    }
    
    private func saveLocalCredits(deviceId: String) {
        UserDefaults.standard.set(credits, forKey: "\(creditsKey)_\(deviceId)")
    }
    
    private func clearLocalCredits(deviceId: String) {
        UserDefaults.standard.removeObject(forKey: "\(creditsKey)_\(deviceId)")
    }
    
    // MARK: - Purchase Integration
    
    // Mock product type for compilation
    struct MockAdaptyProduct {
        let vendorProductId: String
        let localizedPrice: String?
    }
    
    func purchaseCredits(product: MockAdaptyProduct) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Mock purchase - always succeeds
            let creditAmount = getCreditAmount(from: product)
            try await addCredits(creditAmount, source: .purchase)
            trackPurchase(product: product)
            isLoading = false
        } catch {
            errorMessage = "Purchase failed"
            isLoading = false
            throw error
        }
    }
    
    func restorePurchases() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Mock restore - always succeeds
            let restoredCredits = credits // Keep current credits
            
            credits = restoredCredits
            
            // Save credits
            switch userState {
            case .anonymous(let deviceId):
                saveAnonymousCredits(deviceId: deviceId)
            case .authenticated(let user):
                try await saveAuthenticatedCredits(userId: user.id)
            }
            
            isLoading = false
        } catch {
            errorMessage = "Restore failed"
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCreditAmount(from product: MockAdaptyProduct) -> Int {
        let vendorId = product.vendorProductId
        
        if vendorId.contains("10") {
            return 10
        } else if vendorId.contains("50") {
            return 50
        } else if vendorId.contains("100") {
            return 100
        } else if vendorId.contains("500") {
            return 500
        }
        
        return 10
    }
    
    // Mock profile type
    struct MockAdaptyProfile {
        let accessLevels: [String: MockAccessLevel]
    }
    
    struct MockAccessLevel {
        let isActive: Bool
    }
    
    private func calculateCreditsFromProfile(_ profile: MockAdaptyProfile) async throws -> Int {
        if profile.accessLevels["pro"]?.isActive == true {
            return 9999
        }
        
        return credits
    }
    
    private func trackPurchase(product: MockAdaptyProduct) {
        UserDefaults.standard.set(true, forKey: "has_purchased")
    }
    
    // MARK: - Backend Response Sync
    
    /// Updates local quota state from backend response after image processing
    /// This ensures UI quota counter stays in sync with backend truth
    func updateFromBackendResponse(credits: Int, quotaUsed: Int, quotaLimit: Int, isPremium: Bool) async {
        // Update credits
        self.credits = credits
        
        // Update quota
        self.dailyQuotaUsed = quotaUsed
        self.dailyQuotaLimit = quotaLimit
        
        // Update premium status
        self.isPremiumUser = isPremium
        
        // Persist to local storage
        saveDailyQuota()
        
        // Save credits based on user state
        switch userState {
        case .anonymous(let deviceId):
            saveAnonymousCredits(deviceId: deviceId)
        case .authenticated(let user):
            do {
                try await saveAuthenticatedCredits(userId: user.id)
            } catch {
                #if DEBUG
                print("❌ Failed to save authenticated credits after backend sync: \(error)")
                #endif
            }
        }
        
        #if DEBUG
        print("✅ HybridCreditManager synced from backend: credits=\(credits), quota=\(quotaUsed)/\(quotaLimit)")
        #endif
    }
}

// MARK: - Models

struct AnonymousCredits: Codable {
    let deviceId: String
    let credits: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case credits
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserCredits: Codable {
    let userId: String
    let credits: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case credits
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum CreditSource: String {
    case purchase = "purchase"
    case migration = "migration"
    case refund = "refund"
}

enum HybridCreditError: LocalizedError {
    case insufficientCredits
    case alreadyAuthenticated
    case migrationFailed
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .insufficientCredits:
            return "You don't have enough credits. Purchase more to continue!"
        case .alreadyAuthenticated:
            return "User is already authenticated"
        case .migrationFailed:
            return "Failed to migrate your credits. Please contact support."
        case .notAuthenticated:
            return "Please sign in to sync your credits"
        }
    }
}

