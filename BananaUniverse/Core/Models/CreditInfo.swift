//
//  CreditInfo.swift
//  BananaUniverse
//
//  Created by AI Assistant on 23.10.2025.
//  Updated: November 13, 2025 - Converted to persistent credit system
//

import Foundation

struct CreditInfo: Codable {
    let creditsRemaining: Int
    let isPremium: Bool
    let idempotent: Bool?  // Indicates cached/idempotent response from backend

    enum CodingKeys: String, CodingKey {
        case creditsRemaining = "credits_remaining"
        case isPremium = "is_premium"
        case idempotent
    }
}

enum CreditError: LocalizedError {
    case insufficientCredits

    var errorDescription: String? {
        switch self {
        case .insufficientCredits:
            return "Insufficient credits. Purchase more credits to continue."
        }
    }
}
