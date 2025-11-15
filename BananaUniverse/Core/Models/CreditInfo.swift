//
//  CreditInfo.swift
//  BananaUniverse
//
//  Created by AI Assistant on 23.10.2025.
//  Updated: November 15, 2025 - Added lifetime credit tracking
//

import Foundation

struct CreditInfo: Codable {
    let creditsRemaining: Int       // Current spendable balance
    let creditsTotal: Int?          // Lifetime total credits (never decreases)
    let initialGrantClaimed: Bool?  // Whether user got their free 10 credits
    let idempotent: Bool?           // Indicates cached/idempotent response from backend

    enum CodingKeys: String, CodingKey {
        case creditsRemaining = "credits_remaining"
        case creditsTotal = "credits_total"
        case initialGrantClaimed = "initial_grant_claimed"
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
