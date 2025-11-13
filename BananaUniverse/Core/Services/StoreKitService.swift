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
import Adapty

/// StoreKit 2 service for handling real Apple subscriptions
@MainActor
class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    
    @Published var products: [Product] = []
    @Published var purchasedProducts: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isPremiumUser = false
    @Published var subscriptionRenewalDate: Date?
    
    // Success alert handling
    @Published var shouldShowSuccessAlert = false
    @Published var successAlertMessage = ""
    
    // Product IDs from App Store Connect
    private let productIds = ["banana_weekly", "banana_yearly"]
    
    // Transaction listener state
    private var transactionListenerTask: Task<Void, Never>?
    
    private init() {
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
        startTransactionListener()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            products = try await Product.products(for: productIds)
            print("✅ Loaded \(products.count) products from App Store")
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("❌ Product loading failed: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase Flow
    
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()

                // Update purchased products
                purchasedProducts.insert(product.id)
                await updateSubscriptionStatus()

                // Sync subscription to Supabase
                await syncSubscriptionToSupabase(transaction: transaction, productId: product.id)

                // Trigger premium status refresh in CreditManager
                await CreditManager.shared.refreshPremiumStatus()

                #if DEBUG
                print("✅ Purchase successful and verified: \(product.id)")
                #endif
                isLoading = false
                return transaction
                
            case .userCancelled:
                #if DEBUG
                print("ℹ️ User cancelled purchase - no success alert")
                #endif
                isLoading = false
                return nil
                
            case .pending:
                print("⏳ Purchase pending approval")
                isLoading = false
                return nil
                
            @unknown default:
                print("❌ Unknown purchase result")
                isLoading = false
                return nil
            }
        } catch {
            // Handle specific error cases without showing success alerts
            if isUserCancelledError(error) || isASDErrorDomain509(error) {
                #if DEBUG
                print("ℹ️ Purchase cancelled or failed (Code=509) - no success alert: \(error.localizedDescription)")
                #endif
                isLoading = false
                return nil
            }
            
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("❌ Purchase error: \(error)")
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            try await Adapty.restorePurchases()
            await updateSubscriptionStatus()
            #if DEBUG
            print("✅ Purchases restored successfully")
            #endif
        } catch {
            errorMessage = "Subscription restore failed – please try again later"
            #if DEBUG
            print("❌ Subscription verification failed: \(error.localizedDescription)")
            #endif
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Subscription Status
    
    func hasActiveSubscription() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable {
                    return true
                }
            }
        }
        return false
    }
    
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        var latestRenewalDate: Date?

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable {
                    hasActiveSubscription = true
                    purchasedProducts.insert(transaction.productID)

                    // Get renewal date from transaction
                    if let renewalDate = transaction.expirationDate {
                        latestRenewalDate = renewalDate
                    }

                    // Sync subscription to Supabase
                    await syncSubscriptionToSupabase(transaction: transaction, productId: transaction.productID)

                    #if DEBUG
                    print("✅ Active subscription found: \(transaction.productID)")
                    #endif
                }
            }
        }

        isPremiumUser = hasActiveSubscription
        subscriptionRenewalDate = latestRenewalDate

        #if DEBUG
        print("📊 Premium status: \(isPremiumUser ? "Active" : "Inactive")")
        if let renewalDate = latestRenewalDate {
            print("📅 Renewal date: \(renewalDate)")
        }
        #endif
    }
    
    // MARK: - Supabase Sync

    /// Syncs StoreKit subscription to Supabase subscriptions table
    private func syncSubscriptionToSupabase(transaction: StoreKit.Transaction, productId: String) async {
        #if DEBUG
        print("🔄 [SUBSCRIPTION] Syncing to Supabase...")
        print("   Transaction ID: \(transaction.id)")
        print("   Product ID: \(productId)")
        if let expirationDate = transaction.expirationDate {
            print("   Expires: \(expirationDate)")
        }
        #endif

        do {
            // Get user state
            let userState = HybridAuthService.shared.userState
            let userId: String? = userState.isAuthenticated ? userState.identifier : nil
            let deviceId: String? = userState.isAuthenticated ? nil : await CreditManager.shared.getDeviceUUID()

            // Prepare parameters for RPC call (must be Encodable - all String values)
            var params: [String: String] = [
                "p_product_id": productId,
                "p_transaction_id": String(transaction.id),
                "p_platform": "ios"
            ]

            if let userId = userId {
                params["p_user_id"] = userId
            }
            if let deviceId = deviceId {
                params["p_device_id"] = deviceId
            }
            if let expirationDate = transaction.expirationDate {
                params["p_expires_at"] = ISO8601DateFormatter().string(from: expirationDate)
            }

            // Call sync_subscription RPC function
            let _ = try await SupabaseService.shared.client
                .rpc("sync_subscription", params: params)
                .execute()

            #if DEBUG
            print("✅ [SUBSCRIPTION] Synced to Supabase successfully")
            #endif

        } catch {
            // Log error but don't fail purchase
            #if DEBUG
            print("⚠️ [SUBSCRIPTION] Failed to sync to Supabase: \(error.localizedDescription)")
            print("   This won't affect the purchase, subscription will sync on next app launch")
            #endif
        }
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
                    
                    // Update subscription status and show success alert on main thread
                    if let self = self {
                        await MainActor.run {
                            Task {
                                await self.updateSubscriptionStatus()
                                // Only show success alert for verified transactions
                                if let transaction = transaction, transaction.productType == .autoRenewable {
                                    self.showSuccessAlertForVerifiedTransaction(transaction)
                                }
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
        isPremiumUser = true
        successAlertMessage = "Welcome to Premium! You now have unlimited access to all features."
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
    
    func getProduct(by id: String) -> Product? {
        return products.first { $0.id == id }
    }
    
    func isProductPurchased(_ product: Product) -> Bool {
        return purchasedProducts.contains(product.id)
    }
    
    // MARK: - Computed Properties
    
    var weeklyProduct: Product? {
        return getProduct(by: "banana_weekly")
    }
    
    var yearlyProduct: Product? {
        return getProduct(by: "banana_yearly")
    }
    
    var hasProducts: Bool {
        return !products.isEmpty
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
