//
//  HybridAuthService.swift
//  noname_banana
//
//  Created by AI Assistant on 14.10.2025.
//

import Foundation
import Supabase
import Combine
import AuthenticationServices
import StableID

/// Manages authentication for both anonymous and authenticated users
@MainActor
class HybridAuthService: ObservableObject {
    static let shared = HybridAuthService()

    @Published var userState: UserState = .anonymous(deviceId: "")  // Will be set in init()
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase: SupabaseService
    private var authStateTask: Task<Void, Never>?

    init(supabase: SupabaseService) {
        self.supabase = supabase

        // CRITICAL: Initialize userState with StableID SYNCHRONOUSLY
        // This prevents race condition where CreditManager.initializeNewUser()
        // is called before checkCurrentUser() completes, causing wrong device ID
        let deviceId = getOrCreateDeviceUUID()
        userState = .anonymous(deviceId: deviceId)

        #if DEBUG
        print("🔐 [HybridAuth] Initialized with StableID: \(deviceId)")
        #endif

        setupAuthStateListener()
        checkCurrentUser()
    }
    
    convenience init() {
        self.init(supabase: SupabaseService.shared)
    }
    
    deinit {
        authStateTask?.cancel()
    }
    
    // MARK: - Initialization
    
    private func setupAuthStateListener() {
        authStateTask = Task {
            await supabase.client.auth.onAuthStateChange { [weak self] event, session in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    // Store the previous state before updating
                    let previousState = self.userState
                    
                    if let session = session {
                        self.userState = .authenticated(user: session.user)
                        // Migrate credits if coming from anonymous state
                        await self.handleAuthenticationStateChange(from: previousState, to: self.userState)
                    } else {
                        // Preserve stable device identifier for anonymous sessions
                        let deviceId = self.getOrCreateDeviceUUID()
                        self.userState = .anonymous(deviceId: deviceId)
                        // Update credit manager with new anonymous state
                        CreditManager.shared.setUserState(self.userState)
                    }
                }
            }
        }
    }
    
    private func checkCurrentUser() {
        Task { @MainActor in
            // Prefer awaiting session restoration from Keychain
            if let session = try? await supabase.getCurrentSession() {
                let user = session.user
                userState = .authenticated(user: user)
                
                // Check for legacy migration even if session exists (in case it was skipped)
                await checkAndMigrateLegacyData()
            } else {
                // No session -> Sign in anonymously
                do {
                    try await signInAnonymously()
                } catch {
                    print("❌ [HybridAuth] Anonymous sign-in failed: \(error)")
                    // Fallback to legacy mode if network fails?
                    // Or just show error?
                    // For now, fallback to legacy local state so app works offline-ish
                    let deviceId = getOrCreateDeviceUUID()
                    userState = .anonymous(deviceId: deviceId)
                }
            }
            
            // Update credit manager with the determined state
            CreditManager.shared.setUserState(userState)
        }
    }
    
    private func handleAuthenticationStateChange(from previousState: UserState, to newState: UserState) async {
        print("🔄 [AUTH] User state transition: \(previousState) → \(newState)")
        
        // CRITICAL: Update quota manager with new state
        CreditManager.shared.setUserState(newState)
        
        // Check for migration when entering authenticated state
        if case .authenticated = newState {
             await checkAndMigrateLegacyData()
        }
    }
    
    // MARK: - Anonymous Authentication
    
    func signInAnonymously() async throws {
        print("🔐 [HybridAuth] Attempting Supabase Anonymous Sign-In...")
        let session = try await supabase.client.auth.signInAnonymously()
        
        userState = .authenticated(user: session.user)
        CreditManager.shared.setUserState(userState)
        
        await checkAndMigrateLegacyData()
    }
    
    private func checkAndMigrateLegacyData() async {
        let deviceId = getOrCreateDeviceUUID()
        
        // REMOVED: UserDefaults check - we want this to run EVERY time to recover credits
        // This is critical for StableID-based credit recovery
        
        print("🔄 [HybridAuth] Running credit recovery for device: \(deviceId)")
        
        do {
            let params = ["p_device_id": deviceId]
            // Call the new recovery RPC that handles both new and existing devices
            let response: [String: AnyJSON] = try await supabase.client
                .rpc("recover_or_init_user", params: params)
                .execute()
                .value
            
            // Extract recovered credits from response
            if let success = response["success"]?.boolValue, success {
                if let credits = response["credits_remaining"]?.intValue {
                    let isNewDevice = response["is_new_device"]?.boolValue ?? false
                    let jobsMoved = response["jobs_moved"]?.intValue ?? 0
                    
                    print("✅ [HybridAuth] Recovery complete: \(credits) credits, new device: \(isNewDevice), jobs moved: \(jobsMoved)")
                    
                    // Update CreditManager with recovered balance
                    await CreditManager.shared.updateFromRecovery(credits: credits)
                } else {
                    print("⚠️ [HybridAuth] Recovery response missing credits field")
                }
            } else {
                let error = response["error"]?.stringValue ?? "Unknown error"
                print("❌ [HybridAuth] Recovery failed: \(error)")
            }
        } catch {
            print("⚠️ [HybridAuth] Recovery RPC call failed: \(error)")
            // Don't fail silently - this is critical for credit persistence
            // Fall back to normal credit loading
            await CreditManager.shared.loadQuota()
        }
    }
    
    // MARK: - Authenticated Authentication
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        
        do {
            let session = try await supabase.client.auth.signIn(
                email: email,
                password: password
            )
            
            
            // Wait a moment for auth listener to fire
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Check if auth state was updated by listener
            
            // If listener didn't fire, manually update state
            if !userState.isAuthenticated {
                let previousState = userState
                userState = .authenticated(user: session.user)
                CreditManager.shared.setUserState(userState)
                await handleAuthenticationStateChange(from: previousState, to: userState)
            }
            
            isLoading = false
        } catch {
            let appError = AppError.from(error)
            errorMessage = appError.errorDescription ?? "Sign in failed"
            isLoading = false
            throw error
        }
    }
    
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        
        do {
            let session = try await supabase.client.auth.signUp(
                email: email,
                password: password
            )
            
            
            // Wait a moment for auth listener to fire
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Check if auth state was updated by listener
            
            // If listener didn't fire, manually update state
            if !userState.isAuthenticated {
                let previousState = userState
                userState = .authenticated(user: session.user)
                CreditManager.shared.setUserState(userState)
                await handleAuthenticationStateChange(from: previousState, to: userState)
            }
            
            isLoading = false
        } catch {
            let appError = AppError.from(error)
            errorMessage = appError.errorDescription ?? "Sign up failed"
            isLoading = false
            throw error
        }
    }
    
    /// Exchanges an Apple ID token (and optional nonce) for a Supabase session.
    func signInWithApple(idToken: String, nonce: String? = nil) async throws {
        isLoading = true
        errorMessage = nil
        
        
        do {
            let credentials = OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
            
            let session = try await supabase.client.auth.signInWithIdToken(credentials: credentials)
            
            
            // Wait a moment for auth listener to fire
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Check if auth state was updated by listener
            
            // If listener didn't fire, manually update state
            if !userState.isAuthenticated {
                let previousState = userState
                userState = .authenticated(user: session.user)
                CreditManager.shared.setUserState(userState)
                await handleAuthenticationStateChange(from: previousState, to: userState)
            }
            
            isLoading = false
        } catch {
            
            // Log Supabase-specific error details
            if let supabaseError = error as? AuthError {
            }
            
            let appError = AppError.from(error)
            errorMessage = appError.errorDescription ?? "Apple Sign-In failed"
            isLoading = false
            throw error
        }
    }
    
    func signOut() async throws {
        isLoading = true
        errorMessage = nil
        
        
        do {
            try await supabase.signOut()
            
            // Switch to anonymous state (Authenticated Anonymous)
            do {
                try await signInAnonymously()
            } catch {
                print("❌ [HybridAuth] Failed to sign in anonymously after sign out: \(error)")
                // Fallback to local state if network fails, but this leaves us without a token
                let deviceId = getOrCreateDeviceUUID()
                userState = .anonymous(deviceId: deviceId)
                CreditManager.shared.setUserState(userState)
            }
            
            // Verify session cleared (best-effort diagnostics)
            let currentUser = supabase.getCurrentUser()
            if currentUser == nil {
            } else {
            }
            do {
                let session = try await supabase.getCurrentSession()
            } catch {
            }
            
            isLoading = false
        } catch {
            let appError = AppError.from(error)
            errorMessage = appError.errorDescription ?? "Password reset failed"
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Helper Methods

    private func getOrCreateDeviceUUID() -> String {
        // StableID is already configured in BananaUniverseApp.init()
        // Migration from UserDefaults happens there before StableID.configure()
        #if DEBUG
        print("🔐 [HybridAuth] Using StableID: \(StableID.id)")
        #endif

        return StableID.id
    }
    
    // MARK: - Computed Properties
    
    var isAuthenticated: Bool {
        return userState.isAuthenticated
    }
    
    var currentUser: User? {
        return userState.user
    }
    
    var deviceId: String? {
        return userState.deviceId
    }
    
    /// Returns true only if user has an email (not anonymous)
    var hasEmail: Bool {
        guard let email = currentUser?.email else { return false }
        return !email.isEmpty
    }
    
    var identifier: String {
        return userState.identifier
    }
}

// MARK: - Apple Sign-In Delegate Wrapper

private class ASAuthorizationControllerDelegateWrapper: NSObject, ASAuthorizationControllerDelegate {
    private let continuation: CheckedContinuation<ASAuthorization, Error>
    
    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
}

// MARK: - Error Management

extension HybridAuthService {
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Error Types

enum HybridAuthError: LocalizedError {
    case invalidAppleCredential
    case migrationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidAppleCredential:
            return "Invalid Apple ID credential"
        case .migrationFailed:
            return "Failed to migrate anonymous data to authenticated account"
        }
    }
}
