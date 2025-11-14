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
        
        do {
            creditProducts = try await Product.products(for: creditProductIds)
            print("✅ Loaded \(creditProducts.count) credit products from App Store")
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
