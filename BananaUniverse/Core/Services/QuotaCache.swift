//
//  QuotaCache.swift
//  BananaUniverse
//
//  Created by Refactor on November 4, 2025.
//  Updated: November 13, 2025 - Converted to persistent credit system
//  Handles credit balance persistence to UserDefaults (single responsibility)
//

import Foundation

/// Persistence layer for credit data
/// Responsible for: Reading/writing to UserDefaults only
struct QuotaCache {
    static let shared = QuotaCache()

    // MARK: - Storage Keys (v3 for credit system)
    private let creditsRemainingKey = "credits_remaining_v3"
    private let premiumStatusKey = "premium_status_v3"
    private let lastUpdateKey = "credits_last_update_v3"

    private init() {}

    // MARK: - Data Model

    struct CachedQuota {
        let creditsRemaining: Int
        let premium: Bool
        let lastUpdate: Date

        var isStale: Bool {
            // Consider cache stale after 5 minutes
            Date().timeIntervalSince(lastUpdate) > 300
        }
    }

    // MARK: - Public API

    /// Saves credit balance to UserDefaults
    /// - Parameters:
    ///   - creditsRemaining: Current credit balance
    ///   - premium: Premium status
    func save(creditsRemaining: Int, premium: Bool) {
        UserDefaults.standard.set(creditsRemaining, forKey: creditsRemainingKey)
        UserDefaults.standard.set(premium, forKey: premiumStatusKey)
        UserDefaults.standard.set(Date(), forKey: lastUpdateKey)

        #if DEBUG
        print("💾 [CACHE] Saved: \(creditsRemaining) credits, premium: \(premium)")
        #endif
    }

    /// Loads credit balance from UserDefaults
    /// - Returns: CachedQuota if data exists, nil otherwise
    func load() -> CachedQuota? {
        // Check if data exists (credits_remaining is required)
        guard UserDefaults.standard.object(forKey: creditsRemainingKey) != nil else {
            #if DEBUG
            print("💾 [CACHE] No cached data found")
            #endif
            return nil
        }

        let cached = CachedQuota(
            creditsRemaining: UserDefaults.standard.integer(forKey: creditsRemainingKey),
            premium: UserDefaults.standard.bool(forKey: premiumStatusKey),
            lastUpdate: UserDefaults.standard.object(forKey: lastUpdateKey) as? Date ?? Date()
        )

        #if DEBUG
        print("💾 [CACHE] Loaded: \(cached.creditsRemaining) credits, premium: \(cached.premium), stale: \(cached.isStale)")
        #endif

        return cached
    }

    /// Clears all cached credit data
    func clear() {
        UserDefaults.standard.removeObject(forKey: creditsRemainingKey)
        UserDefaults.standard.removeObject(forKey: premiumStatusKey)
        UserDefaults.standard.removeObject(forKey: lastUpdateKey)

        #if DEBUG
        print("💾 [CACHE] Cleared all credit data")
        #endif
    }

    /// Migrates old cache keys to new v3 keys (credit system)
    func migrateFromV1IfNeeded() {
        // v2 quota keys
        let quotaUsedKey = "quota_used_v2"
        let quotaLimitKey = "quota_limit_v2"
        let oldPremiumKey = "premium_status_v2"

        // v1 quota keys
        let oldQuotaKey = "daily_quota_v1"
        let oldPremiumKeyV1 = "premium_status_v1"

        // Check if v2 data exists and new data doesn't
        if UserDefaults.standard.object(forKey: quotaUsedKey) != nil,
           UserDefaults.standard.object(forKey: creditsRemainingKey) == nil {

            let used = UserDefaults.standard.integer(forKey: quotaUsedKey)
            let limit = UserDefaults.standard.integer(forKey: quotaLimitKey)
            let premium = UserDefaults.standard.bool(forKey: oldPremiumKey)

            // Convert quota to credits: remaining = limit - used
            let creditsRemaining = max(0, limit - used)

            // Migrate to new credit system
            save(creditsRemaining: creditsRemaining, premium: premium)

            // Clean up old keys
            UserDefaults.standard.removeObject(forKey: quotaUsedKey)
            UserDefaults.standard.removeObject(forKey: quotaLimitKey)
            UserDefaults.standard.removeObject(forKey: oldPremiumKey)

            #if DEBUG
            print("💾 [CACHE] Migrated from v2 quota: \(used)/\(limit) → \(creditsRemaining) credits, premium: \(premium)")
            #endif
        }
        // Check if v1 data exists
        else if UserDefaults.standard.object(forKey: oldQuotaKey) != nil,
                UserDefaults.standard.object(forKey: creditsRemainingKey) == nil {

            let oldUsed = UserDefaults.standard.integer(forKey: oldQuotaKey)
            let oldPremium = UserDefaults.standard.bool(forKey: oldPremiumKeyV1)

            // v1 had limit of 3, convert to credits
            let creditsRemaining = max(0, 3 - oldUsed)

            // Migrate to new credit system
            save(creditsRemaining: creditsRemaining, premium: oldPremium)

            // Clean up old keys
            UserDefaults.standard.removeObject(forKey: oldQuotaKey)
            UserDefaults.standard.removeObject(forKey: oldPremiumKeyV1)

            #if DEBUG
            print("💾 [CACHE] Migrated from v1 quota: \(oldUsed)/3 → \(creditsRemaining) credits, premium: \(oldPremium)")
            #endif
        }
    }
}
