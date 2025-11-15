/**
 * IAP Manager Service
 * Purpose: Handle In-App Purchases with StoreKit 2
 *
 * Usage:
 * let iap = IAPManager.shared
 * await iap.loadProducts()
 * try await iap.purchase(productId: "com.yourapp.credits.medium")
 */

import Foundation
import StoreKit

@MainActor
class IAPManager: ObservableObject {
    static let shared = IAPManager()

    @Published var products: [Product] = []
    @Published var purchasedProducts: Set<String> = []
    @Published var isLoading = false

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        self.isLoading = true

        do {
            // Define your product IDs
            let productIds: [String] = [
                "com.yourapp.credits.small",
                "com.yourapp.credits.medium",
                "com.yourapp.credits.large",
            ]

            self.products = try await Product.products(for: productIds)
            print("Loaded \(products.count) products")
        } catch {
            print("Failed to load products: \(error)")
        }

        self.isLoading = false
    }

    // MARK: - Purchase

    func purchase(productId: String) async throws {
        guard let product = products.first(where: { $0.id == productId }) else {
            throw IAPError.productNotFound
        }

        // Start purchase
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Verify transaction
            let transaction = try checkVerified(verification)

            // Verify with backend
            try await verifyWithBackend(transaction: transaction)

            // Finish transaction
            await transaction.finish()

            // Update purchased products
            await updatePurchasedProducts()

        case .userCancelled:
            throw IAPError.userCancelled

        case .pending:
            throw IAPError.paymentPending

        @unknown default:
            throw IAPError.unknown
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async throws {
        // Sync all transactions
        try await AppStore.sync()

        // Update purchased products
        await updatePurchasedProducts()
    }

    // MARK: - Verify with Backend

    private func verifyWithBackend(transaction: Transaction) async throws {
        guard let token = try? await SupabaseAuth.shared.getAccessToken() else {
            throw IAPError.notAuthenticated
        }

        let supabaseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
        let url = URL(string: "\(supabaseURL)/functions/v1/verify-iap")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = VerifyIAPRequest(
            transactionId: String(transaction.id),
            productId: transaction.productID
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw IAPError.verificationFailed
        }

        let verifyResponse = try JSONDecoder().decode(VerifyIAPResponse.self, from: data)

        if !verifyResponse.success {
            throw IAPError.verificationFailed
        }

        // Update credits in local state
        await CreditSystem.shared.getBalance()

        print("Credits granted: \(verifyResponse.creditsGranted ?? 0)")
    }

    // MARK: - Listen for Transactions

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Listen for transaction updates
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Verify with backend
                    await self.verifyWithBackend(transaction: transaction)

                    // Finish transaction
                    await transaction.finish()

                    // Update purchased products
                    await self.updatePurchasedProducts()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Update Purchased Products

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        // Get all transactions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchased.insert(transaction.productID)
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }

        self.purchasedProducts = purchased
    }

    // MARK: - Verify Transaction

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw IAPError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Get Product Price

    func getProductPrice(productId: String) -> String? {
        guard let product = products.first(where: { $0.id == productId }) else {
            return nil
        }
        return product.displayPrice
    }
}

// MARK: - Models

enum IAPError: Error {
    case productNotFound
    case userCancelled
    case paymentPending
    case verificationFailed
    case notAuthenticated
    case unknown

    var localizedDescription: String {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .userCancelled:
            return "Purchase cancelled"
        case .paymentPending:
            return "Payment pending"
        case .verificationFailed:
            return "Failed to verify purchase"
        case .notAuthenticated:
            return "Not authenticated"
        case .unknown:
            return "Unknown error"
        }
    }
}

struct VerifyIAPRequest: Codable {
    let transactionId: String
    let productId: String

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case productId = "product_id"
    }
}

struct VerifyIAPResponse: Codable {
    let success: Bool
    let creditsGranted: Int?
    let productName: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case creditsGranted = "credits_granted"
        case productName = "product_name"
        case error
    }
}
