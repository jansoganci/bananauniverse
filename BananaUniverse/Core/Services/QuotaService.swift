//
//  QuotaService.swift
//  BananaUniverse
//
//  Created by Refactor on November 4, 2025.
//  Updated: November 13, 2025 - Converted to persistent credit system
//  Handles all credit-related network calls (single responsibility)
//

import Foundation
import Supabase

/// Network layer for credit operations
/// Responsible for: RPC calls to Supabase backend only
actor QuotaService {
    static let shared = QuotaService()

    private let supabase = SupabaseService.shared

    private init() {}

    // MARK: - Public API

    /// Fetches current credit balance from backend
    /// - Parameters:
    ///   - userId: Authenticated user ID (nil for anonymous)
    ///   - deviceId: Device ID for anonymous users (nil for authenticated)
    /// - Returns: CreditInfo with current credit balance
    /// - Throws: QuotaError on network/decode failure
    func getQuota(userId: String?, deviceId: String?) async throws -> CreditInfo {
        // Define response structure matching backend RPC
        struct RPCResponse: Decodable {
            let credits_remaining: Int
            let is_premium: Bool
            let success: Bool?
        }

        do {
            // Build params dictionary with proper types
            var params: [String: AnyJSON] = [:]
            if let userId = userId {
                params["p_user_id"] = AnyJSON.string(userId)
            } else {
                params["p_user_id"] = AnyJSON.null
            }
            if let deviceId = deviceId {
                params["p_device_id"] = AnyJSON.string(deviceId)
            } else {
                params["p_device_id"] = AnyJSON.null
            }

            // Directly decode the RPC response as CreditInfo
            struct RPCCreditResponse: Decodable {
                let credits_remaining: Int
                let is_premium: Bool
                let success: Bool?
                let idempotent: Bool?
            }

            let rpcResponse: RPCCreditResponse = try await supabase.client
                .rpc("get_credits", params: params)
                .execute()
                .value

            return CreditInfo(
                creditsRemaining: rpcResponse.credits_remaining,
                isPremium: rpcResponse.is_premium,
                idempotent: rpcResponse.idempotent
            )

        } catch let error as QuotaError {
            throw error
        } catch {
            throw QuotaError.network(error)
        }
    }

    // MARK: - Note on Credit Consumption
    // Credit consumption is now handled directly by Edge Functions (submit-job)
    // No client-side consumeQuota() method needed
    // Credits are atomically deducted in the database via consume_credits() RPC
}
