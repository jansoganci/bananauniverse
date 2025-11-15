//
//  SupabaseService.swift
//  BananaUniverse
//
//  Created by AI Assistant on 13.10.2025.
//

import Foundation
import Supabase

@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    private init() {
        guard let supabaseURL = URL(string: Config.supabaseURL) else {
            fatalError("Invalid Supabase URL: \(Config.supabaseURL)")
        }
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: Config.supabaseAnonKey
        )
    }
    
    // MARK: - Authentication
    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(
            email: email,
            password: password
        )
    }
    
    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(
            email: email,
            password: password
        )
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    func getCurrentUser() -> User? {
        return client.auth.currentUser
    }
    
    func getCurrentSession() async throws -> Session? {
        return try await client.auth.session
    }
    
    // MARK: - Storage
    func downloadImage(path: String) async throws -> Data {
        return try await client.storage
            .from(Config.supabaseBucket)
            .download(path: path)
    }
    
    /// Upload image to Supabase Storage and return public URL
    func uploadImageToStorage(imageData: Data, fileName: String? = nil) async throws -> String {
        
        // Generate unique filename if not provided
        let finalFileName = fileName ?? "\(UUID().uuidString).jpg"
        
        // Get user state for path organization
        let userState = HybridAuthService.shared.userState
        let userOrDeviceID = userState.identifier
        let path = "uploads/\(userOrDeviceID)/\(finalFileName)"
        
        
        // Debug: Check current session and JWT
        do {
            let session = try await getCurrentSession()
            
            if let token = session?.accessToken {
                // Decode JWT to see what's inside
                let parts = token.split(separator: ".")
                if parts.count == 3 {
                    let payload = String(parts[1])
                    if let data = Data(base64Encoded: payload + "==") {
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        }
                    }
                }
            }
        } catch {
        }
        
        // Upload to Supabase Storage
        let _ = try await client.storage
            .from(Config.supabaseBucket)
            .upload(path, data: imageData, options: FileOptions(
                contentType: "image/jpeg",
                upsert: true
            ))
        
        
        // Get public URL
        let publicURL = try await client.storage
            .from(Config.supabaseBucket)
            .getPublicURL(path: path)
        
        
        return publicURL.absoluteString
    }
    
    // MARK: - Async Polling (Phase 2 Migration)

    /// Submit image job to async queue (new polling architecture)
    /// Returns job_id immediately for polling
    func submitImageJob(
        imageURL: String,
        prompt: String
    ) async throws -> SubmitJobResponse {

        // Get user state from hybrid auth service
        let userState = HybridAuthService.shared.userState

        // Generate client request ID for idempotency
        let clientRequestId = UUID().uuidString

        // Prepare request body
        var body: [String: Any] = [
            "image_url": imageURL,
            "prompt": prompt,
            "client_request_id": clientRequestId
        ]

        // Add user identification
        if userState.isAuthenticated {
            body["user_id"] = userState.identifier
            body["device_id"] = await CreditManager.shared.getDeviceUUID()
        } else {
            body["device_id"] = userState.identifier
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        // Call submit-job Edge Function
        guard let functionURL = URL(string: "\(Config.supabaseURL)/functions/v1/submit-job") else {
            throw SupabaseError.invalidURL
        }

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"

        // Set authorization header
        if userState.isAuthenticated {
            if let session = try? await client.auth.session {
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            }
        } else {
            request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userState.identifier, forHTTPHeaderField: "device-id")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        let (responseData, urlResponse) = try await URLSession.shared.data(for: request)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        if httpResponse.statusCode == 402 {
            // Try to parse error response to get actual credit balance from backend
            struct ErrorResponse: Decodable {
                let quota_info: QuotaInfo?
            }
            struct QuotaInfo: Decodable {
                let credits_remaining: Int
            }
            
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: responseData),
               let creditsRemaining = errorResponse.quota_info?.credits_remaining {
                // Update credit manager with actual backend balance
                await CreditManager.shared.updateFromBackendResponse(creditsRemaining: creditsRemaining)
                #if DEBUG
                print("⚠️ [CREDITS] Backend returned 402. Updated frontend balance to: \(creditsRemaining)")
                #endif
            }
            throw SupabaseError.insufficientCredits
        }

        if httpResponse.statusCode != 200 {
            throw SupabaseError.serverError("Job submission failed with status: \(httpResponse.statusCode)")
        }

        // Parse response
        let response = try JSONDecoder().decode(SubmitJobResponse.self, from: responseData)

        return response
    }

    /// Fetch job result from webhook architecture
    /// Returns status and image URL if completed
    func getJobResult(jobId: String) async throws -> GetResultResponse {

        // Get user state from hybrid auth service
        let userState = HybridAuthService.shared.userState

        // Prepare request body
        var body: [String: Any] = [
            "job_id": jobId
        ]

        // Add user identification
        if userState.isAuthenticated {
            body["user_id"] = userState.identifier
            body["device_id"] = await CreditManager.shared.getDeviceUUID()
        } else {
            body["device_id"] = userState.identifier
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        // Call get-result Edge Function
        guard let functionURL = URL(string: "\(Config.supabaseURL)/functions/v1/get-result") else {
            throw SupabaseError.invalidURL
        }

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"

        // Set authorization header
        if userState.isAuthenticated {
            if let session = try? await client.auth.session {
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            }
        } else {
            request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userState.identifier, forHTTPHeaderField: "device-id")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        let (responseData, urlResponse) = try await URLSession.shared.data(for: request)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw SupabaseError.serverError("Job not found")
        }

        if httpResponse.statusCode != 200 {
            throw SupabaseError.serverError("Failed to fetch job result with status: \(httpResponse.statusCode)")
        }

        // Parse response
        let response = try JSONDecoder().decode(GetResultResponse.self, from: responseData)

        return response
    }

    /// Get count of active (pending/processing) jobs for current user
    func getActiveJobCount() async throws -> Int {
        let userState = HybridAuthService.shared.userState
        
        var body: [String: Any?] = [:]
        
        if userState.isAuthenticated {
            body["p_user_id"] = userState.identifier
            body["p_device_id"] = nil
        } else {
            body["p_user_id"] = nil
            body["p_device_id"] = userState.identifier
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        guard let functionURL = URL(string: "\(Config.supabaseURL)/rest/v1/rpc/get_active_job_count") else {
            throw SupabaseError.invalidURL
        }
        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (responseData, _) = try await URLSession.shared.data(for: request)
        
        if let count = try? JSONDecoder().decode(Int.self, from: responseData) {
            return count
        }
        
        return 0 // Fail open
    }
    
    // MARK: - Library / Job History
    
    /// Fetch user's job history from database
    /// Works for both authenticated and anonymous users
    func fetchUserJobs(
        userState: UserState,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [JobRecord] {
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let response: [JobRecord]
            
            if userState.isAuthenticated {
                // Authenticated users: use direct table query
                
                let query = client
                    .from("jobs")
                    .select()
                    .eq("status", value: "completed")
                    .eq("user_id", value: userState.identifier)
                    .order("completed_at", ascending: false)
                    .limit(limit)
                    .range(from: offset, to: offset + limit - 1)
                
                response = try await query
                    .execute()
                    .value
                    
            } else {
                // Anonymous users: use custom function to bypass RLS
                
                response = try await client
                    .rpc("get_jobs_by_device_id", params: ["device_id_param": userState.identifier])
                    .execute()
                    .value
            }
            
            
            // Debug: Print first few job details if any exist
            if !response.isEmpty {
                for (index, job) in response.prefix(3).enumerated() {
                }
            } else {
            }
            
            return response
            
        } catch {
            throw error
        }
    }
    
    /// Generate signed URL for a storage path
    func getSignedURL(for path: String, expiresIn: Int = 2592000) async throws -> String {
        // 30 days expiration by default
        let result = try await client.storage
            .from(Config.supabaseBucket)
            .createSignedURL(path: path, expiresIn: expiresIn)
        
        return result.absoluteString
    }
    
    // MARK: - Database
    func getUserProfile() async throws -> UserProfile {
        guard let user = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        let response: UserProfile = try await client
            .from("profiles")
            .select()
            .eq("id", value: user.id.uuidString)
            .single()
            .execute()
            .value
        
        return response
    }
    
    func updateUserProfile(_ profile: UserProfile) async throws {
        guard let user = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        try await client
            .from("profiles")
            .update(profile)
            .eq("id", value: user.id.uuidString)
            .execute()
    }
    
    // MARK: - Account Deletion
    
    /// Delete user account and all associated data
    /// This method will be called by the RPC function that handles complete data cleanup
    func deleteUserAccount() async throws {
        
        guard let user = getCurrentUser() else {
            throw SupabaseError.notAuthenticated
        }
        
        
        do {
            // Call the RPC function that handles complete account deletion
            // This will delete all user data including:
            // - User profile
            // - Job history
            // - Credit transactions
            // - Storage files
            // - Auth user record
            let _ = try await client
                .rpc("delete_user_account", params: ["user_id": user.id.uuidString])
                .execute()
            
            
            // Account deletion completed
            
        } catch {
            throw error
        }
    }
}

// MARK: - Models

struct AIProcessResponse: Codable {
    let jobId: String
    let status: String
    let resultUrl: String?
    let resultUrls: [String]?
    let description: String?
    let seed: Int?
    let modelUsed: String
    let usage: UsageInfo?
    let userType: String?
    
    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case resultUrl = "result_url"
        case resultUrls = "result_urls"
        case description
        case seed
        case modelUsed = "model_used"
        case usage
        case userType = "user_type"
    }
}

struct JobSubmissionResponse: Codable {
    let jobId: String
    let status: String
    let message: String
    let falRequestId: String?
    let estimatedTime: Int?
    let pollUrl: String?
    let usage: UsageInfo?
    let userType: String?
    
    // ✅ REMOVED CodingKeys - using convertFromSnakeCase instead
    // This eliminates the conflict between automatic and manual key mapping
}

struct UsageInfo: Codable {
    let requestsToday: Int
    let requestsMonth: Int
    
    // ✅ REMOVED CodingKeys - using convertFromSnakeCase instead
    // Note: subscription_tier column may exist in DB but is ignored
}

struct JobStatusResponse: Codable {
    let jobId: String
    let status: String
    let model: String
    let resultUrl: String?
    let errorMessage: String?
    let message: String?
    let elapsedTime: Int?
    let processingTime: Int?
    let estimatedRemaining: Int?
    let falRequestId: String?
    let falStatus: String?
    let createdAt: String
    let updatedAt: String
    let completedAt: String?
    
    // ✅ REMOVED CodingKeys - using convertFromSnakeCase instead
    // This eliminates the conflict between automatic and manual key mapping
}

struct UserProfile: Codable {
    let id: UUID
    let email: String
    let requestsUsedToday: Int
    let requestsUsedThisMonth: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case requestsUsedToday = "requests_used_today"
        case requestsUsedThisMonth = "requests_used_this_month"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        // Note: subscription_tier column may exist in DB but is ignored
    }
}

struct JobRecord: Codable, Identifiable {
    let id: UUID
    let userId: UUID?
    let deviceId: String?
    let model: String
    let status: String
    let inputURL: String?
    let outputURL: String?
    let options: JobOptions?
    let errorMessage: String?
    let falRequestId: String?
    let createdAt: Date
    let completedAt: Date?
    let updatedAt: Date
    let processingTimeSeconds: Int?
    let falStatus: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceId = "device_id"
        case model, status
        case inputURL = "input_url"
        case outputURL = "output_url"
        case options
        case errorMessage = "error_message"
        case falRequestId = "fal_request_id"
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case updatedAt = "updated_at"
        case processingTimeSeconds = "processing_time_seconds"
        case falStatus = "fal_status"
    }
}

struct JobOptions: Codable {
    let prompt: String?
    let timestamp: Int?
    let falImageUrl: String?
    let processingTimeSeconds: Int?
    
    enum CodingKeys: String, CodingKey {
        case prompt
        case timestamp
        case falImageUrl = "fal_image_url"
        case processingTimeSeconds = "processing_time_seconds"
    }
}

struct ErrorResponse: Codable {
    let error: String
    let details: String?
}

enum SupabaseError: Error, LocalizedError {
    case notAuthenticated
    case insufficientCredits
    case invalidResponse
    case serverError(String)
    case noSession
    case processingFailed(String)
    case timeout
    case rateLimitExceeded
    case quotaExceeded
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to use this feature"
        case .insufficientCredits:
            return "You don't have enough credits. Purchase more credits to continue!"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        case .noSession:
            return "No active session found"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .timeout:
            return "Processing timed out. Please try again."
        case .rateLimitExceeded:
            return "You have too many jobs processing. Please wait for one to complete."
        case .quotaExceeded:
            return "Daily quota exceeded. Come back tomorrow or upgrade for unlimited access."
        case .invalidURL:
            return "Invalid URL configuration. Please contact support."
        }
    }
    
    /// Maps SupabaseError to user-friendly AppError
    var appError: AppError {
        switch self {
        case .notAuthenticated, .noSession:
            return .signInRequired
        case .insufficientCredits:
            return .insufficientCredits
        case .timeout:
            return .processingTimeout
        case .processingFailed(let message):
            return .processingFailed(message)
        case .rateLimitExceeded:
            return .dailyQuotaExceeded
        case .quotaExceeded:
            return .dailyQuotaExceeded
        case .serverError(let message):
            return .unknown("Server error: \(message)")
        case .invalidResponse:
            return .invalidResponse
        case .invalidURL:
            return .serviceUnavailable
        }
    }
}
