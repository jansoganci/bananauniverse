//
//  QuotaInfo.swift
//  BananaUniverse
//
//  Created by AI Assistant on 23.10.2025.
//

import Foundation

struct QuotaInfo: Codable {
    let credits: Int
    let quotaUsed: Int
    let quotaLimit: Int
    let quotaRemaining: Int
    let isPremium: Bool
    
    enum CodingKeys: String, CodingKey {
        case credits
        case quotaUsed = "quota_used"
        case quotaLimit = "quota_limit"
        case quotaRemaining = "quota_remaining"
        case isPremium = "is_premium"
    }
}

enum QuotaExceededError: LocalizedError {
    case dailyLimitReached
    
    var errorDescription: String? {
        switch self {
        case .dailyLimitReached:
            return "Daily limit reached. Please try again tomorrow or upgrade to Premium."
        }
    }
}
