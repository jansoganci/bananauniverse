//
//  ThemeService.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2025.
//  Service for fetching themes/tools from Supabase database
//

import Foundation

/// Protocol for theme fetching (enables testing with mocks)
protocol ThemeServiceProtocol {
    func fetchThemes() async throws -> [Theme]
}

/// Service for fetching themes from Supabase REST API
class ThemeService: ThemeServiceProtocol {
    static let shared = ThemeService()

    private let baseURL: String
    private let anonKey: String
    private let session: URLSession

    // Cache for reducing API calls
    private var cachedThemes: [Theme]?
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

    /// Fetches all available themes from Supabase
    /// - Returns: Array of themes sorted by featured status and name
    /// - Throws: AppError if network or decoding fails
    func fetchThemes() async throws -> [Theme] {
        // Return cache if valid
        if let cached = cachedThemes,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidity {
            print("📦 ThemeService: Returning cached themes (\(cached.count) themes)")
            return cached
        }

        // Fetch from API
        print("🌐 ThemeService: Fetching themes from API...")
        let themes = try await fetchFromAPI()

        // Update cache
        cachedThemes = themes
        cacheTimestamp = Date()

        print("✅ ThemeService: Fetched \(themes.count) themes from database")
        return themes
    }

    /// Clears the cache to force a fresh fetch on next call
    func clearCache() {
        cachedThemes = nil
        cacheTimestamp = nil
        print("🗑️ ThemeService: Cache cleared")
    }

    // MARK: - Private Methods

    private func fetchFromAPI() async throws -> [Theme] {
        // Build query URL
        let queryParams = [
            "is_available=eq.true",
            "select=*",
            "order=is_featured.desc,name.asc"
        ].joined(separator: "&")

        guard let url = URL(string: "\(baseURL)/rest/v1/themes?\(queryParams)") else {
            print("❌ ThemeService: Invalid URL")
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
            print("❌ ThemeService: Invalid response type")
            throw AppError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ ThemeService: HTTP \(httpResponse.statusCode) - \(errorString)")
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
            print("⚠️ ThemeService: Failed to parse date: \(dateString)")
            return Date()
        }

        do {
            let themes = try decoder.decode([Theme].self, from: data)
            return themes
        } catch {
            print("❌ ThemeService: Decoding failed - \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Raw JSON (first 500 chars): \(String(jsonString.prefix(500)))")
            }
            throw AppError.invalidResponse
        }
    }
}

// MARK: - Mock Service for Testing

#if DEBUG
/// Mock theme service for SwiftUI previews and testing
class MockThemeService: ThemeServiceProtocol {
    var shouldFail = false
    var mockThemes: [Theme] = []

    func fetchThemes() async throws -> [Theme] {
        if shouldFail {
            throw AppError.networkUnavailable
        }

        // Return mock themes if provided, otherwise empty array
        return mockThemes
    }
}
#endif
