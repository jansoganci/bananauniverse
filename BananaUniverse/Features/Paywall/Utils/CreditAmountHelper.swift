//
//  CreditAmountHelper.swift
//  BananaUniverse
//
//  Helper for credit amount calculations
//

import Foundation

struct CreditAmountHelper {
    static func getAmount(from productId: String) -> Int {
        switch productId {
        case "credits_10": return 10
        case "credits_25": return 25
        case "credits_50": return 50
        case "credits_100": return 100
        default: return 0
        }
    }
}

