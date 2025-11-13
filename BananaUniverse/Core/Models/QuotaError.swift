//
//  QuotaError.swift
//  BananaUniverse
//
//  Created by Refactor on November 4, 2025.
//  Unified error handling for quota system
//

import Foundation

/// Unified error enum for all quota-related failures
enum QuotaError: LocalizedError {
    case network(Error)
    case decode(String)
    case server(Int, String)
    case rateLimited
    case invalidResponse(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .network(let error):
            return "Network error: \(error.localizedDescription)"

        case .decode(let message):
            return "Failed to decode response: \(message)"

        case .server(let code, let message):
            return "Server error \(code): \(message)"

        case .rateLimited:
            return "Daily limit reached. Please try again tomorrow or upgrade to Premium."

        case .invalidResponse(let details):
            return "Invalid response from server: \(details)"

        case .unauthorized:
            return "Authentication required. Please sign in."
        }
    }

    /// User-facing error message (safe to display in UI)
    var displayMessage: String {
        switch self {
        case .network:
            return "Network error. Please check your connection and try again."

        case .decode, .invalidResponse:
            return "Something went wrong. Please try again."

        case .server:
            return "Server error. Please try again later."

        case .rateLimited:
            return "You've reached your daily limit. Upgrade to Premium for unlimited access!"

        case .unauthorized:
            return "Please sign in to continue."
        }
    }

    /// Whether this error should trigger a retry
    var isRetryable: Bool {
        switch self {
        case .network:
            return true
        case .server(let code, _):
            return code >= 500  // Retry server errors, not client errors
        case .decode, .invalidResponse, .rateLimited, .unauthorized:
            return false
        }
    }

    /// Whether this error indicates rate limiting
    var isRateLimit: Bool {
        if case .rateLimited = self {
            return true
        }
        return false
    }
}
