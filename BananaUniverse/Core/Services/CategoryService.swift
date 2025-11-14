//
//  CategoryService.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025.
//  Service for fetching categories from Supabase database
//

import Foundation

/// Protocol for category fetching (enables testing with mocks)
protocol CategoryServiceProtocol {
    func fetchCategories() async throws -> [Category]
}

/// Service for fetching categories from Supabase REST API
class CategoryService: CategoryServiceProtocol {
    static let shared = CategoryService()

    private let baseURL: String
    private let anonKey: String
    private let session: URLSession

    // Cache for reducing API calls
    private var cachedCategories: [Category]?
    private var cacheTimestamp: Date?
    private let cacheValidity: TimeInterval = 300 // 5 minutes

    init(
        baseURL: String = Config.supabaseURL,
        anonKey: String = Config.supabaseAnonKey,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.session = session
    }

    // MARK: - Public API

    /// Fetches all active categories from Supabase
    /// - Returns: Array of categories sorted by display_order
    /// - Throws: AppError if network or decoding fails
    func fetchCategories() async throws -> [Category] {
        // Return cache if valid
        if let cached = cachedCategories,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidity {
            print("📦 CategoryService: Returning cached categories (\(cached.count) categories)")
            return cached
        }

        // Fetch from API
        print("🌐 CategoryService: Fetching categories from API...")
        let categories = try await fetchFromAPI()

        // Update cache
        cachedCategories = categories
        cacheTimestamp = Date()

        print("✅ CategoryService: Fetched \(categories.count) categories from database")
        return categories
    }

    /// Clears the cache to force a fresh fetch on next call
    func clearCache() {
        cachedCategories = nil
        cacheTimestamp = nil
        print("🗑️ CategoryService: Cache cleared")
    }

    // MARK: - Private Methods

    private func fetchFromAPI() async throws -> [Category] {
        // Build query URL
        let queryParams = [
            "is_active=eq.true",
            "select=*",
            "order=display_order.asc"
        ].joined(separator: "&")

        guard let url = URL(string: "\(baseURL)/rest/v1/categories?\(queryParams)") else {
            print("❌ CategoryService: Invalid URL")
            throw AppError.invalidResponse
        }

        // Create request with Supabase headers
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.timeoutInterval = 30

        // Execute request
        let (data, response) = try await session.data(for: request)

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ CategoryService: Invalid response type")
            throw AppError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ CategoryService: HTTP \(httpResponse.statusCode) - \(errorString)")
            }

            switch httpResponse.statusCode {
            case 401, 403:
                throw AppError.authenticationFailed
            case 404:
                throw AppError.serviceUnavailable
            case 500...599:
                throw AppError.serverUnavailable
            default:
                throw AppError.invalidResponse
            }
        }

        // Decode JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Fallback to standard ISO8601
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Last resort: return current date
            print("⚠️ CategoryService: Failed to parse date: \(dateString)")
            return Date()
        }

        do {
            let categories = try decoder.decode([Category].self, from: data)
            return categories
        } catch {
            print("❌ CategoryService: Decoding failed - \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Raw JSON (first 500 chars): \(String(jsonString.prefix(500)))")
            }
            throw AppError.invalidResponse
        }
    }
}

// MARK: - Mock Service for Testing

#if DEBUG
/// Mock category service for SwiftUI previews and testing
class MockCategoryService: CategoryServiceProtocol {
    var shouldFail = false
    var mockCategories: [Category] = []

    func fetchCategories() async throws -> [Category] {
        if shouldFail {
            throw AppError.networkUnavailable
        }

        // Return mock categories if provided, otherwise use default mocks
        return mockCategories.isEmpty ? Category.mockCategories : mockCategories
    }
}
#endif

