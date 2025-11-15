/**
 * Credit System Service
 * Purpose: Manage user credits (check balance, deduct, add)
 *
 * Usage:
 * let credits = CreditSystem.shared
 * let balance = try await credits.getBalance()
 * try await credits.deductCredits(amount: 1, reason: "video_generation")
 */

import Foundation
import Supabase

@MainActor
class CreditSystem: ObservableObject {
    static let shared = CreditSystem()

    @Published var balance: Int = 0
    @Published var isLoading = false

    private let supabase: SupabaseClient

    private init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "")!,
            supabaseKey: ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
        )
    }

    // MARK: - Get Balance

    func getBalance() async throws -> Int {
        guard let userId = try await SupabaseAuth.shared.currentUser?.id else {
            throw CreditError.notAuthenticated
        }

        let response: User = try await supabase
            .from("users")
            .select("credits_remaining")
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        self.balance = response.creditsRemaining
        return response.creditsRemaining
    }

    // MARK: - Deduct Credits

    func deductCredits(amount: Int, reason: String = "usage") async throws {
        guard let userId = try await SupabaseAuth.shared.currentUser?.id else {
            throw CreditError.notAuthenticated
        }

        // Get access token
        let token = try await SupabaseAuth.shared.getAccessToken()

        // Call update-credits function
        let url = URL(string: "\(supabase.supabaseURL)/functions/v1/update-credits")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = UpdateCreditsRequest(
            userId: userId,
            amount: amount,
            action: "deduct",
            reason: reason
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(UpdateCreditsResponse.self, from: data)

        if !response.success {
            throw CreditError.insufficientCredits
        }

        self.balance = response.creditsRemaining ?? 0
    }

    // MARK: - Add Credits (from IAP)

    func addCredits(
        amount: Int,
        transactionId: String,
        reason: String = "iap_purchase"
    ) async throws {
        guard let userId = try await SupabaseAuth.shared.currentUser?.id else {
            throw CreditError.notAuthenticated
        }

        let token = try await SupabaseAuth.shared.getAccessToken()

        let url = URL(string: "\(supabase.supabaseURL)/functions/v1/update-credits")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = UpdateCreditsRequest(
            userId: userId,
            amount: amount,
            action: "add",
            reason: reason,
            transactionId: transactionId
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(UpdateCreditsResponse.self, from: data)

        if response.success {
            self.balance = response.creditsRemaining ?? 0
        }
    }

    // MARK: - Get Transaction History

    func getTransactionHistory() async throws -> [CreditTransaction] {
        guard let userId = try await SupabaseAuth.shared.currentUser?.id else {
            throw CreditError.notAuthenticated
        }

        let response: [CreditTransaction] = try await supabase
            .from("quota_log")
            .select("*")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(20)
            .execute()
            .value

        return response
    }

    // MARK: - Check if User Can Afford

    func canAfford(amount: Int) async throws -> Bool {
        let balance = try await getBalance()
        return balance >= amount
    }
}

// MARK: - Models

enum CreditError: Error {
    case notAuthenticated
    case insufficientCredits
    case invalidAmount
}

struct User: Codable {
    let creditsRemaining: Int

    enum CodingKeys: String, CodingKey {
        case creditsRemaining = "credits_remaining"
    }
}

struct UpdateCreditsRequest: Codable {
    let userId: String
    let amount: Int
    let action: String
    let reason: String
    let transactionId: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case amount
        case action
        case reason
        case transactionId = "transaction_id"
    }

    init(userId: String, amount: Int, action: String, reason: String, transactionId: String? = nil) {
        self.userId = userId
        self.amount = amount
        self.action = action
        self.reason = reason
        self.transactionId = transactionId
    }
}

struct UpdateCreditsResponse: Codable {
    let success: Bool
    let creditsRemaining: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case creditsRemaining = "credits_remaining"
        case error
    }
}

struct CreditTransaction: Codable, Identifiable {
    let id: Int
    let change: Int
    let reason: String
    let balanceBefore: Int
    let balanceAfter: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case change
        case reason
        case balanceBefore = "balance_before"
        case balanceAfter = "balance_after"
        case createdAt = "created_at"
    }
}
