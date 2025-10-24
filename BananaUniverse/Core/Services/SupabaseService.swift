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
    
    // MARK: - Quota Management
    
    /// Consume quota using the new quota system
    func consumeQuota(userId: String?, deviceId: String?, isPremium: Bool) async throws -> QuotaInfo {
        // Generate client request ID for idempotency
        let clientRequestId = UUID().uuidString
        
        // Prepare request body
        var body: [String: Any] = [
            "client_request_id": clientRequestId,
            "is_premium": isPremium
        ]
        
        if let userId = userId {
            body["user_id"] = userId
        }
        if let deviceId = deviceId {
            body["device_id"] = deviceId
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        guard let functionURL = URL(string: "\(Config.supabaseURL)/functions/v1/process-image") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId ?? "", forHTTPHeaderField: "device-id")
        request.httpBody = jsonData
        
        // Set authorization header
        if let userId = userId {
            // Authenticated user - try to get session token
            if let session = try? await client.auth.session {
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            }
        } else {
            // Anonymous user
            request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }
        
        request.timeoutInterval = 30
        
        let (responseData, urlResponse) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 {
            throw SupabaseError.quotaExceeded
        }
        
        if httpResponse.statusCode != 200 {
            throw SupabaseError.serverError("Quota consumption failed with status: \(httpResponse.statusCode)")
        }
        
        // Parse response
        let response = try JSONDecoder().decode(SteveJobsProcessResponse.self, from: responseData)
        
        guard let quotaInfo = response.quotaInfo else {
            throw SupabaseError.invalidResponse
        }
        
        return quotaInfo
    }

    // MARK: - AI Processing
    
    /// 🍎 STEVE JOBS STYLE: Direct image processing with new process-image edge function
    /// Works for both authenticated and anonymous users
    /// Returns processed image URL directly - no polling needed!
    func processImageSteveJobsStyle(
        imageURL: String,
        prompt: String,
        options: [String: Any] = [:]
    ) async throws -> SteveJobsProcessResponse {
        
        // Check if user can process image using quota system
        guard await HybridCreditManager.shared.canProcessImage() else {
            throw SupabaseError.insufficientCredits
        }
        
        // Get user state from hybrid auth service
        let userState = HybridAuthService.shared.userState
        
        if userState.isAuthenticated {
        } else {
        }
        
        // Generate client request ID for idempotency
        let clientRequestId = UUID().uuidString
        
        // Prepare request body
        var body: [String: Any] = [
            "image_url": imageURL,
            "prompt": prompt,
            "client_request_id": clientRequestId
        ]
        
        // Add user identification and premium status
        if userState.isAuthenticated {
            body["user_id"] = userState.identifier
            // Also add device_id as fallback for authenticated users
            body["device_id"] = await HybridCreditManager.shared.getDeviceUUID()
        } else {
            body["device_id"] = userState.identifier
        }
        
        // Add premium status
        body["is_premium"] = await HybridCreditManager.shared.isPremiumUser
        
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        do {
            // Call the new Steve Jobs style edge function
            guard let functionURL = URL(string: "\(Config.supabaseURL)/functions/v1/process-image") else {
                throw SupabaseError.invalidURL
            }
            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            
            // CRITICAL FIX: Use actual user session token for authenticated users
            if userState.isAuthenticated {
                // Get the user's session token
                if let session = try? await client.auth.session {
                    request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
                    #if DEBUG
                    print("🔑 Using authenticated user token for API call")
                    #endif
                } else {
                    // Fallback to anon key if session retrieval fails
                    request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
                    #if DEBUG
                    print("⚠️ Failed to get session, using anon key")
                    #endif
                }
            } else {
                // Anonymous users use anon key
                request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
                #if DEBUG
                print("🔓 Using anon key for anonymous user")
                #endif
            }
            
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(userState.identifier, forHTTPHeaderField: "device-id") // For anonymous users
            request.httpBody = jsonData
            
            // Set timeout to 60 seconds for processing
            request.timeoutInterval = 60
            
            let (responseData, urlResponse) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw SupabaseError.invalidResponse
            }
            
            
            // Parse response
            let response = try JSONDecoder().decode(SteveJobsProcessResponse.self, from: responseData)
            
            if response.success {
                // CRITICAL: Update quota from backend response
                if let quotaInfo = response.quotaInfo {
                    await HybridCreditManager.shared.updateFromBackendResponse(
                        quotaUsed: quotaInfo.quotaUsed,
                        quotaLimit: quotaInfo.quotaLimit,
                        isPremium: quotaInfo.isPremium
                    )
                    #if DEBUG
                    print("✅ [QUOTA] Updated from backend: \(quotaInfo.quotaUsed)/\(quotaInfo.quotaLimit)")
                    #endif
                }
                return response
            } else {
                throw SupabaseError.processingFailed(response.error ?? "Processing failed")
            }
            
        } catch {
            throw error
        }
    }
    
    /// Process image with AI using raw image data (recommended for iOS)
    /// Works for both authenticated and anonymous users
    func processImageData(
        model: String,
        imageData: Data,
        options: [String: Any] = [:]
    ) async throws -> AIProcessResponse {
        
        // Check if user can process image (includes quota validation)
        guard await HybridCreditManager.shared.canProcessImage() else {
            throw SupabaseError.insufficientCredits
        }
        
        // Get user state from hybrid auth service
        let userState = HybridAuthService.shared.userState
        
        if userState.isAuthenticated {
        } else {
        }
        
        // Convert image data to base64
        let base64String = imageData.base64EncodedString()
        let imageDataString = "data:image/jpeg;base64,\(base64String)"
        
        var body: [String: Any] = [
            "model": model,
            "image_data": imageDataString,
            "options": options
        ]
        
        // Add user context based on state
        if userState.isAuthenticated {
            body["user_id"] = userState.identifier
        } else {
            body["device_id"] = userState.identifier
        }
        
        // Add premium status
        body["is_premium"] = await HybridCreditManager.shared.isPremiumUser
        
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        do {
            
            // Use URLSession directly instead of Supabase SDK to avoid response parsing issues
            guard let functionURL = URL(string: "\(Config.supabaseURL)/functions/v1/ai-process") else {
                throw SupabaseError.invalidURL
            }
            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (responseData, urlResponse) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = urlResponse as? HTTPURLResponse {
                
                // Handle 202 Accepted (async processing)
                if httpResponse.statusCode == 202 {
                    
                    // Parse job_id from response
                    if let responseString = String(data: responseData, encoding: .utf8) {
                    }
                    
                    // For now, throw error - we need to implement polling
                    throw SupabaseError.processingFailed("Async processing not yet supported. Please wait and try again.")
                }
            }
            
            
            // Debug: Print raw response data
            if let responseString = String(data: responseData, encoding: .utf8) {
            } else {
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let response = try decoder.decode(AIProcessResponse.self, from: responseData)
                
                // ✅ Credit consumption is now handled by the edge function
                
                return response
            } catch DecodingError.dataCorrupted(let context) {
                throw SupabaseError.processingFailed("Data corrupted")
            } catch DecodingError.keyNotFound(let key, let context) {
                throw SupabaseError.processingFailed("Key '\(key)' not found")
            } catch DecodingError.valueNotFound(let value, let context) {
                throw SupabaseError.processingFailed("Value '\(value)' not found")
            } catch DecodingError.typeMismatch(let type, let context) {
                throw SupabaseError.processingFailed("Type '\(type)' mismatch")
            } catch {
                throw error
            }
            
        } catch {
            // ❌ Processing failed - credit NOT spent
            
            // Try to extract error details
            if let data = error as? Data {
                let errorString = String(data: data, encoding: .utf8) ?? "Could not decode error"
            }
            
            // Check if it's a URLError or other network error
            if let urlError = error as? URLError {
            }
            
            throw error
        }
    }
    
    // MARK: - Async Processing (V2)
    
    /// Process image with AI using V2 async API (returns 202 immediately)
    /// Works for both authenticated and anonymous users
    func processImageDataV2(
        model: String,
        imageURL: String,
        options: [String: Any] = [:]
    ) async throws -> JobSubmissionResponse {
        
        // Check if user can process image (includes credits and quota validation)
        guard await HybridCreditManager.shared.canProcessImage() else {
            throw SupabaseError.insufficientCredits
        }
        
        // Get user state from hybrid auth service
        let userState = HybridAuthService.shared.userState
        
        if userState.isAuthenticated {
        } else {
        }
        
        // Use image URL directly (no base64 conversion needed)
        var body: [String: Any] = [
            "model": model,
            "image_url": imageURL,
            "options": options
        ]
        
        // Add user context based on state
        if userState.isAuthenticated {
            body["user_id"] = userState.identifier
        } else {
            body["device_id"] = userState.identifier
        }
        
        // Add premium status
        body["is_premium"] = await HybridCreditManager.shared.isPremiumUser
        
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        do {
            // Use URLSession directly for V2 endpoint
            guard let functionURL = URL(string: "\(Config.supabaseURL)/functions/v1/ai-process-v2") else {
                throw SupabaseError.invalidURL
            }
            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (responseData, urlResponse) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw SupabaseError.invalidResponse
            }
            
            
            // V2 returns 202 Accepted
            if httpResponse.statusCode == 202 {
                
                // Debug: Print raw response
                if let rawResponse = String(data: responseData, encoding: .utf8) {
                } else {
                }
                
                // Enhanced debugging for decode process
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                // Try to parse as JSON first to see structure
                do {
                    if let jsonObject = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                        for (key, value) in jsonObject {
                        }
                    }
                } catch {
                }
                
                let response = try decoder.decode(JobSubmissionResponse.self, from: responseData)
                
                // ✅ CONSUME QUOTA IMMEDIATELY ON ACCEPTANCE
                _ = try await HybridCreditManager.shared.spendCreditWithQuota()
                
                return response
            } else if httpResponse.statusCode == 429 {
                // Rate limit or concurrent limit exceeded
                if let errorString = String(data: responseData, encoding: .utf8) {
                }
                throw SupabaseError.rateLimitExceeded
            } else {
                // Other errors
                if let errorString = String(data: responseData, encoding: .utf8) {
                }
                throw SupabaseError.serverError("Failed to submit job")
            }
            
        } catch let error as SupabaseError {
            throw error
        } catch DecodingError.keyNotFound(let key, let context) {
            throw SupabaseError.processingFailed("Key '\(key)' not found in response")
        } catch DecodingError.typeMismatch(let type, let context) {
            throw SupabaseError.processingFailed("Type mismatch: expected \(type)")
        } catch DecodingError.valueNotFound(let value, let context) {
            throw SupabaseError.processingFailed("Value '\(value)' not found")
        } catch DecodingError.dataCorrupted(let context) {
            throw SupabaseError.processingFailed("Data corrupted: \(context.debugDescription)")
        } catch {
            throw error
        }
    }
    
    /// Poll job status until completion with progress callbacks
    func pollJobStatus(
        jobId: String,
        deviceId: String? = nil,
        onProgress: @escaping (JobStatusResponse) -> Void
    ) async throws -> JobStatusResponse {
        
        var attempts = 0
        let maxAttempts = 120 // 10 minutes max (with exponential backoff)
        var pollInterval: UInt64 = 3_000_000_000 // Start with 3 seconds
        
        while attempts < maxAttempts {
            do {
                // Build URL with parameters
                var urlComponents = URLComponents(string: "\(Config.supabaseURL)/functions/v1/job-status")!
                var queryItems = [URLQueryItem(name: "job_id", value: jobId)]
                
                // Add device_id for anonymous users
                if let deviceId = deviceId {
                    queryItems.append(URLQueryItem(name: "device_id", value: deviceId))
                }
                
                urlComponents.queryItems = queryItems
                
                guard let url = urlComponents.url else {
                    throw SupabaseError.invalidURL
                }
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
                request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
                
                let (responseData, _) = try await URLSession.shared.data(for: request)
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let status = try decoder.decode(JobStatusResponse.self, from: responseData)
                
                
                // Call progress callback
                onProgress(status)
                
                // Check if done
                if status.status == "completed" {
                    return status
                } else if status.status == "failed" {
                    throw SupabaseError.processingFailed(status.errorMessage ?? "Unknown error")
                }
                
                // Exponential backoff: 3s → 5s → 8s → 10s (max)
                try await Task.sleep(nanoseconds: pollInterval)
                
                if pollInterval < 10_000_000_000 {
                    pollInterval = min(pollInterval + 2_000_000_000, 10_000_000_000)
                }
                
                attempts += 1
                
            } catch let error as SupabaseError {
                throw error
            } catch {
                
                // Don't fail on network errors, just retry
                if attempts >= maxAttempts - 1 {
                    throw SupabaseError.timeout
                }
                
                try await Task.sleep(nanoseconds: pollInterval)
                attempts += 1
            }
        }
        
        throw SupabaseError.timeout
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
    
    /// Upscale image (convenience method)
    func upscaleImage(
        imageData: Data,
        upscaleFactor: Int = 2,
        creativity: Double = 0.35,
        resemblance: Double = 0.6
    ) async throws -> AIProcessResponse {
        let options: [String: Any] = [
            "upscale_factor": upscaleFactor,
            "creativity": creativity,
            "resemblance": resemblance
        ]
        
        
        do {
            let response = try await processImageData(
                model: "upscale",
                imageData: imageData,
                options: options
            )
            return response
        } catch {
            if let supabaseError = error as? SupabaseError {
            }
            throw error
        }
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

// 🍎 STEVE JOBS STYLE RESPONSE MODEL
struct SteveJobsProcessResponse: Codable {
    let success: Bool
    let processedImageURL: String?
    let error: String?
    let rateLimitInfo: RateLimitInfo?  // Deprecated, keeping for backward compatibility
    let quotaInfo: QuotaInfo?
    
    enum CodingKeys: String, CodingKey {
        case success
        case processedImageURL = "processed_image_url"
        case error
        case rateLimitInfo = "rate_limit_info"
        case quotaInfo = "quota_info"
    }
}


struct RateLimitInfo: Codable {
    let requestsToday: Int
    let limit: Int
    let resetTime: String
    
    enum CodingKeys: String, CodingKey {
        case requestsToday = "requests_today"
        case limit
        case resetTime = "reset_time"
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
    let subscriptionTier: String
    
    // ✅ REMOVED CodingKeys - using convertFromSnakeCase instead
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
    let subscriptionTier: String
    let requestsUsedToday: Int
    let requestsUsedThisMonth: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case subscriptionTier = "subscription_tier"
        case requestsUsedToday = "requests_used_today"
        case requestsUsedThisMonth = "requests_used_this_month"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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
