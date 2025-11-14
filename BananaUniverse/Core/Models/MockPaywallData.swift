//
//  MockPaywallData.swift
//  BananaUniverse
//
//  Created by AI Assistant on 14.10.2025.
//  Mock data for paywall system
//

import Foundation

// MARK: - Mock Product Structure

/// Mock product for paywall testing
struct MockProduct {
    let id: String
    let vendorProductId: String
    let localizedTitle: String
    let localizedDescription: String
    let localizedPrice: String
    let price: NSDecimalNumber
    let currencyCode: String
    let subscriptionPeriod: String?
    let trialPeriod: String?
    let isTrialAvailable: Bool
    let savings: String?
}

// MARK: - Mock Paywall Data

class MockPaywallData {
    static let shared = MockPaywallData()
    
    private init() {}
    
    // MARK: - Mock Products
    
    var weeklyProduct: MockProduct {
        MockProduct(
            id: "weekly_pro",
            vendorProductId: "banana_weekly",
            localizedTitle: "paywall_weekly_title".localized,
            localizedDescription: "paywall_weekly_description".localized,
            localizedPrice: "paywall_weekly_price".localized,
            price: NSDecimalNumber(string: "4.99"),
            currencyCode: "USD",
            subscriptionPeriod: "1 week",
            trialPeriod: nil,
            isTrialAvailable: false,
            savings: nil
        )
    }
    
    var yearlyProduct: MockProduct {
        MockProduct(
            id: "yearly_pro",
            vendorProductId: "banana_yearly",
            localizedTitle: "paywall_yearly_title".localized,
            localizedDescription: "paywall_yearly_description".localized,
            localizedPrice: "paywall_yearly_price".localized,
            price: NSDecimalNumber(string: "79.99"),
            currencyCode: "USD",
            subscriptionPeriod: "1 year",
            trialPeriod: "3 days",
            isTrialAvailable: true,
            savings: "paywall_yearly_savings".localized
        )
    }
    
    var allProducts: [MockProduct] {
        [weeklyProduct, yearlyProduct]
    }
    
    // MARK: - Mock Benefits
    
    var benefits: [MockBenefit] {
        [
            MockBenefit(
                icon: "sparkles",
                title: "paywall_benefit_1_title".localized,
                description: "paywall_benefit_1_description".localized
            ),
            MockBenefit(
                icon: "bolt.fill",
                title: "paywall_benefit_2_title".localized,
                description: "paywall_benefit_2_description".localized
            ),
            MockBenefit(
                icon: "star.fill",
                title: "paywall_benefit_3_title".localized,
                description: "paywall_benefit_3_description".localized
            )
        ]
    }
    
    // MARK: - Mock Purchase Simulation
    
    func simulatePurchase(product: MockProduct) async throws -> MockPurchaseResult {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Simulate occasional failures (10% chance)
        if Int.random(in: 1...10) == 1 {
            throw MockPurchaseError.purchaseFailed
        }
        
        return MockPurchaseResult(
            productId: product.id,
            success: true,
            message: "paywall_purchase_success".localized
        )
    }
    
    func simulateRestore() async throws -> MockRestoreResult {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Simulate occasional failures (5% chance)
        if Int.random(in: 1...20) == 1 {
            throw MockPurchaseError.restoreFailed
        }
        
        return MockRestoreResult(
            success: true,
            message: "paywall_restore_success".localized,
            restoredProducts: [weeklyProduct.id, yearlyProduct.id]
        )
    }
}

// MARK: - Supporting Structures

struct MockBenefit {
    let icon: String
    let title: String
    let description: String
}

struct MockPurchaseResult {
    let productId: String
    let success: Bool
    let message: String
}

struct MockRestoreResult {
    let success: Bool
    let message: String
    let restoredProducts: [String]
}

enum MockPurchaseError: LocalizedError {
    case purchaseFailed
    case restoreFailed
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .purchaseFailed:
            return "paywall_error_purchase_failed".localized
        case .restoreFailed:
            return "paywall_error_restore_failed".localized
        case .productNotFound:
            return "paywall_error_product_not_found".localized
        }
    }
}

// MARK: - A/B Testing Variants

enum PaywallVariant: String, CaseIterable {
    case equalLayout = "equal_layout"
    case annualHighlight = "annual_highlight"
    
    var displayName: String {
        switch self {
        case .equalLayout:
            return "Equal Layout"
        case .annualHighlight:
            return "Annual Highlight"
        }
    }
}

// MARK: - Mock A/B Test Data

extension MockPaywallData {
    func getVariant() -> PaywallVariant {
        // In a real implementation, this would come from your A/B testing service
        // For now, we'll randomly assign variants
        return PaywallVariant.allCases.randomElement() ?? .equalLayout
    }
    
    func shouldShowTrialBadge() -> Bool {
        // Show trial badge for annual highlight variant
        return getVariant() == .annualHighlight
    }
    
    func shouldHighlightAnnual() -> Bool {
        // Highlight annual card for annual highlight variant
        return getVariant() == .annualHighlight
    }
}

