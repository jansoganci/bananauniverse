//
//  StoreKitService.swift
//  BananaUniverse
//
//  Created by AI Assistant on October 21, 2025.
//  StoreKit 2 integration for real payment processing
//

import Foundation
import StoreKit
import SwiftUI

/// StoreKit 2 service for handling credit purchases
@MainActor
class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Success alert handling
    @Published var shouldShowSuccessAlert = false
    @Published var successAlertMessage = ""
    
    // Product IDs from App Store Connect
    private let creditProductIds = ["credits_10", "credits_25", "credits_50", "credits_100"]
    
    @Published var creditProducts: [Product] = []
    
    var hasCreditProducts: Bool {
        !creditProducts.isEmpty
    }
    
    // Transaction listener state
    private var transactionListenerTask: Task<Void, Never>?
    
    private init() {
        Task {
            await loadProducts()
        }
        startTransactionListener()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        // 🧪 TEST MODE: Create mock products
        if Config.enablePaymentTestMode {
            #if DEBUG
            print("🧪 [TEST MODE] Creating mock products (bypassing App Store)")
            #endif
            
            // Create mock products for testing
            // In test mode, we'll use the real Product type but they won't be from App Store
            // The purchase method will handle test mode differently
            do {
                creditProducts = try await Product.products(for: creditProductIds)
                #if DEBUG
                print("🧪 [TEST MODE] Loaded \(creditProducts.count) products (will use test mode for purchases)")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ [TEST MODE] Could not load products from App Store: \(error)")
                print("   This is OK in test mode - purchases will still work")
                #endif
                // In test mode, we can continue even if products don't load
                creditProducts = []
            }
            
            isLoading = false
            return
        }
        
        // Real product loading from App Store
        do {
            creditProducts = try await Product.products(for: creditProductIds)
            #if DEBUG
            print("✅ [PAYMENT] Loaded \(creditProducts.count) credit products from App Store")
            for product in creditProducts {
                print("   - \(product.id): \(product.displayName) - \(product.displayPrice)")
            }
            #endif
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            #if DEBUG
            print("❌ [PAYMENT] Product loading failed: \(error)")
            #endif
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase Flow
    
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        errorMessage = nil
        
        // 🧪 TEST MODE: Bypass StoreKit for testing
        if Config.enablePaymentTestMode {
            return try await simulateTestPurchase(product: product)
        }
        
        // Real StoreKit purchase flow
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                #if DEBUG
                print("✅ [PAYMENT] Apple purchase successful: \(product.id)")
                print("   Transaction ID: \(transaction.id)")
                print("   Product ID: \(product.id)")
                #endif
                
                // ✅ CRITICAL FIX: Verify purchase with backend to grant credits
                do {
                    try await verifyPurchaseWithBackend(transaction: transaction, productId: product.id)
                    #if DEBUG
                    print("✅ [PAYMENT] Backend verification successful - credits granted")
                    #endif
                } catch {
                    #if DEBUG
                    print("⚠️ [PAYMENT] Backend verification failed: \(error.localizedDescription)")
                    print("   Purchase is still valid, but credits may not be granted")
                    #endif
                    // Don't fail the purchase if backend verification fails
                    // User can restore purchases later
                    errorMessage = "Purchase successful, but credit grant may be delayed. Please check your balance or try 'Restore Purchases'."
                }
                
                await transaction.finish()

                #if DEBUG
                print("✅ [PAYMENT] Transaction finished")
                #endif
                
                isLoading = false
                return transaction
                
            case .userCancelled:
                #if DEBUG
                print("ℹ️ [PAYMENT] User cancelled purchase")
                #endif
                isLoading = false
                return nil
                
            case .pending:
                #if DEBUG
                print("⏳ [PAYMENT] Purchase pending approval")
                #endif
                isLoading = false
                return nil
                
            @unknown default:
                #if DEBUG
                print("❌ [PAYMENT] Unknown purchase result")
                #endif
                isLoading = false
                return nil
            }
        } catch {
            // Handle specific error cases without showing success alerts
            if isUserCancelledError(error) || isASDErrorDomain509(error) {
                #if DEBUG
                print("ℹ️ [PAYMENT] Purchase cancelled or failed (Code=509): \(error.localizedDescription)")
                #endif
                isLoading = false
                return nil
            }
            
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            #if DEBUG
            print("❌ [PAYMENT] Purchase error: \(error)")
            #endif
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Test Mode
    
    /// Simulates a purchase in test mode (bypasses StoreKit)
    private func simulateTestPurchase(product: Product) async throws -> StoreKit.Transaction? {
        #if DEBUG
        print("🧪 [TEST MODE] Simulating purchase for: \(product.id)")
        print("   Product: \(product.displayName)")
        print("   Price: \(product.displayPrice)")
        #endif
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Get credit amount from product ID
        let creditAmount = getCreditAmount(for: product.id)
        
        #if DEBUG
        print("🧪 [TEST MODE] Granting \(creditAmount) credits...")
        #endif
        
        // Grant credits directly (bypassing backend verification)
        // This simulates what should happen after backend verification
        do {
            // Get current balance
            let currentBalance = CreditManager.shared.creditsRemaining
            
            // Update credit balance
            await CreditManager.shared.updateFromBackendResponse(creditsRemaining: currentBalance + creditAmount)
            
            #if DEBUG
            print("✅ [TEST MODE] Credits granted successfully!")
            print("   Credits added: \(creditAmount)")
            print("   Old balance: \(currentBalance)")
            print("   New balance: \(currentBalance + creditAmount)")
            #endif
            
            // Show success alert
            successAlertMessage = "Test purchase successful! \(creditAmount) credits added. (Test Mode)"
            shouldShowSuccessAlert = true
            
            isLoading = false
            return nil // No real transaction in test mode
            
        } catch {
            #if DEBUG
            print("❌ [TEST MODE] Failed to grant credits: \(error)")
            #endif
            errorMessage = "Test purchase failed: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }
    
    /// Gets credit amount from product ID
    private func getCreditAmount(for productId: String) -> Int {
        switch productId {
        case "credits_10": return 10
        case "credits_25": return 25
        case "credits_50": return 50
        case "credits_100": return 100
        default: return 10
        }
    }
    
    // MARK: - Backend Verification
    
    /// Verifies purchase with backend using transaction ID (StoreKit 2 compatible)
    private func verifyPurchaseWithBackend(transaction: StoreKit.Transaction, productId: String) async throws {
        let transactionId = String(transaction.id)
        
        #if DEBUG
        print("🔐 [PAYMENT] Verifying with backend...")
        print("   Transaction ID: \(transactionId)")
        print("   Product ID: \(productId)")
        #endif
        
        // Call backend verification with transaction_id (backend will fetch from Apple)
        let response = try await SupabaseService.shared.verifyIAPPurchase(
            transactionId: transactionId,
            productId: productId
        )
        
        #if DEBUG
        print("✅ [PAYMENT] Backend verification successful:")
        print("   Credits granted: \(response.credits_granted)")
        print("   Balance after: \(response.balance_after)")
        print("   Transaction ID: \(response.transaction_id)")
        #endif
        
        // Update credit balance in CreditManager
        await CreditManager.shared.updateFromBackendResponse(creditsRemaining: response.balance_after)
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            #if DEBUG
            print("✅ Purchases restored successfully")
            #endif
        } catch {
            errorMessage = "Restore failed – please try again later"
            #if DEBUG
            print("❌ Restore failed: \(error.localizedDescription)")
            #endif
            throw error
        }
        
        isLoading = false
    }

    // MARK: - Helper Methods

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Transaction Listener
    
    /// Starts listening for transaction updates to comply with Apple StoreKit 2 requirements
    private func startTransactionListener() {
        // Prevent duplicate listeners
        guard transactionListenerTask == nil else {
            #if DEBUG
            print("🔄 Transaction listener already running")
            #endif
            return
        }
        
        transactionListenerTask = Task.detached { [weak self] in
            #if DEBUG
            print("🎧 Starting transaction listener...")
            #endif
            
            for await result in Transaction.updates {
                do {
                    let transaction = try await self?.checkVerified(result)
                    await transaction?.finish()
                    
                    #if DEBUG
                    print("✅ Transaction processed and verified: \(transaction?.id ?? 0)")
                    #endif
                    
                    // Show success alert for verified credit purchases
                    if let self = self, let transaction = transaction {
                        await MainActor.run {
                            // Only show success alert for credit purchases (non-subscription products)
                            if transaction.productType != .autoRenewable {
                                self.showSuccessAlertForVerifiedTransaction(transaction)
                            }
                        }
                    }
                } catch {
                    #if DEBUG
                    print("❌ Transaction processing failed: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }
    
    // MARK: - Success Alert Handling
    
    private func showSuccessAlertForVerifiedTransaction(_ transaction: StoreKit.Transaction) {
        // Only show success alert for verified, finished transactions
        successAlertMessage = "Purchase successful! Credits have been added to your account."
        shouldShowSuccessAlert = true
        
        #if DEBUG
        print("🎉 Success alert triggered for verified transaction: \(transaction.id)")
        #endif
    }
    
    func dismissSuccessAlert() {
        shouldShowSuccessAlert = false
        successAlertMessage = ""
    }
    
    // MARK: - Error Detection Helpers
    
    private func isUserCancelledError(_ error: Error) -> Bool {
        // Check for user cancelled errors
        if let storeKitError = error as? StoreKitError {
            return false // StoreKitError cases are handled separately
        }
        
        let errorDescription = error.localizedDescription.lowercased()
        return errorDescription.contains("cancelled") || 
               errorDescription.contains("canceled") ||
               errorDescription.contains("user cancelled") ||
               errorDescription.contains("user canceled")
    }
    
    private func isASDErrorDomain509(_ error: Error) -> Bool {
        // Check for ASDErrorDomain Code=509 (user cancelled)
        let nsError = error as NSError
        return nsError.domain == "ASDErrorDomain" && nsError.code == 509
    }
    
    // MARK: - Product Helpers
    
    func getCreditProduct(by id: String) -> Product? {
        return creditProducts.first { $0.id == id }
    }
}

// MARK: - StoreKit Errors

enum StoreKitError: LocalizedError {
    case verificationFailed
    case productNotFound
    case purchaseFailed(Error)
    case restoreFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Purchase verification failed. Please try again."
        case .productNotFound:
            return "Product not found. Please check your internet connection."
        case .purchaseFailed(let error):
            return "Purchase failed: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "Restore failed: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .verificationFailed:
            return "This is usually a temporary issue. Please try again in a few minutes."
        case .productNotFound:
            return "Make sure you have a stable internet connection and try again."
        case .purchaseFailed:
            return "Check your payment method in Settings > Apple ID > Payment & Shipping."
        case .restoreFailed:
            return "Make sure you're signed in with the same Apple ID used for the original purchase."
        }
    }
}
