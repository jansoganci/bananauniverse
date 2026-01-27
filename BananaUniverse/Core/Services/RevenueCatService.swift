//
//  RevenueCatService.swift
//  BananaUniverse
//
//  Created by AI Assistant on January 27, 2026.
//  RevenueCat integration for subscription and credit management
//

import Foundation
import RevenueCat
import SwiftUI

/// RevenueCat service for handling offerings and purchases
@MainActor
class RevenueCatService: ObservableObject {
    static let shared = RevenueCatService()
    
    @Published var offerings: Offerings?
    @Published var currentOffering: Offering?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Success alert handling
    @Published var shouldShowSuccessAlert = false
    @Published var successAlertMessage = ""
    
    private init() {
        Task {
            await fetchOfferings()
        }
    }
    
    // MARK: - Fetch Offerings
    
    func fetchOfferings() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedOfferings = try await Purchases.shared.offerings()
            self.offerings = fetchedOfferings
            self.currentOffering = fetchedOfferings.current
            
            #if DEBUG
            if let current = fetchedOfferings.current {
                print("✅ [RevenueCat] Current offering loaded with \(current.availablePackages.count) packages")
                for package in current.availablePackages {
                    print("   - \(package.identifier): \(package.storeProduct.localizedTitle) - \(package.storeProduct.localizedPriceString)")
                }
            } else {
                print("⚠️ [RevenueCat] No current offering found")
            }
            #endif
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            #if DEBUG
            print("❌ [RevenueCat] Offerings fetch failed: \(error)")
            #endif
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase Flow
    
    func purchase(_ package: Package) async throws -> CustomerInfo? {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            // 1. Transaction ID Extraction with Fallback
            var transactionId = result.transaction?.transactionIdentifier
            
            // Fallback: RevenueCat sometimes finishes the transaction before returning here
            if transactionId == nil {
                #if DEBUG
                print("ℹ️ [RevenueCat] result.transaction was nil, checking nonSubscriptionTransactions...")
                #endif
                transactionId = result.customerInfo.nonSubscriptionTransactions.last?.transactionIdentifier
            }
            
            // 2. Safety Check - Do not proceed without a valid ID
            guard let finalTransactionId = transactionId, !finalTransactionId.isEmpty else {
                #if DEBUG
                print("❌ [RevenueCat] Purchase succeeded but no Transaction ID found.")
                #endif
                isLoading = false
                // Instead of failing completely, we'll try to sync anyway but with a warning
                successAlertMessage = "Purchase successful! If credits don't appear, please tap 'Restore Purchases'."
                shouldShowSuccessAlert = true
                return result.customerInfo
            }

            let productId = package.storeProduct.productIdentifier
            
            #if DEBUG
            print("✅ [RevenueCat] Purchase successful: \(productId)")
            print("🚀 [Backend] Verifying -> TransactionID: \(finalTransactionId), ProductID: \(productId)")
            #endif
            
            // 3. Backend Verification
            do {
                try await verifyPurchaseWithBackend(transactionId: finalTransactionId, productId: productId)
                
                #if DEBUG
                print("✅ [RevenueCat] Backend update successful")
                #endif
                
                successAlertMessage = "Purchase successful! Your credits have been added."
                shouldShowSuccessAlert = true
            } catch {
                #if DEBUG
                print("⚠️ [RevenueCat] Backend update failed: \(error.localizedDescription)")
                #endif
                // Still show success alert but with sync warning
                successAlertMessage = "Purchase successful! If your credits don't appear shortly, please tap 'Restore Purchases'."
                shouldShowSuccessAlert = true
            }
            
            isLoading = false
            return result.customerInfo
            
        } catch let error as RevenueCat.ErrorCode {
            if error == .purchaseCancelledError {
                #if DEBUG
                print("ℹ️ [RevenueCat] User cancelled purchase")
                #endif
                isLoading = false
                return nil
            }
            
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            isLoading = false
            throw error
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async throws -> CustomerInfo {
        isLoading = true
        errorMessage = nil
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            #if DEBUG
            print("✅ [RevenueCat] Purchases restored successfully")
            #endif
            isLoading = false
            return customerInfo
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCreditAmount(from identifier: String) -> Int {
        // Handle RevenueCat package identifiers (e.g., "$rc_onetime_credits_10") 
        // or whatever identifiers are set up in the dashboard.
        // Assuming identifiers contain the credit amount for simplicity.
        if identifier.contains("10") { return 10 }
        if identifier.contains("25") { return 25 }
        if identifier.contains("50") { return 50 }
        if identifier.contains("100") { return 100 }
        return 0
    }
    
    private func verifyPurchaseWithBackend(transactionId: String, productId: String) async throws {
        // Reusing the backend verification logic from StoreKitService
        // This ensures the credits are granted in Supabase
        _ = try await SupabaseService.shared.verifyIAPPurchase(
            transactionId: transactionId,
            productId: productId
        )
        
        // Refresh CreditManager balance
        await CreditManager.shared.loadQuota()
    }
    
    func dismissSuccessAlert() {
        shouldShowSuccessAlert = false
        successAlertMessage = ""
    }
}
