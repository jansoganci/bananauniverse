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

/// Manages authentication for both anonymous and authenticated users
@MainActor
class HybridAuthService: ObservableObject {
    static let shared = HybridAuthService()
    
    @Published var userState: UserState = .anonymous(deviceId: UUID().uuidString)
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase: SupabaseService
    private var authStateTask: Task<Void, Never>?
    
    init(supabase: SupabaseService) {
        self.supabase = supabase
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
                        HybridCreditManager.shared.setUserState(self.userState)
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
            } else if let user = supabase.getCurrentUser() {
                // Fallback synchronous check
                userState = .authenticated(user: user)
            } else {
                let deviceId = getOrCreateDeviceUUID()
                userState = .anonymous(deviceId: deviceId)
            }
            
            // Update credit manager with the determined state
            HybridCreditManager.shared.setUserState(userState)
        }
    }
    
    private func handleAuthenticationStateChange(from previousState: UserState, to newState: UserState) async {
        print("🔄 [AUTH] User state transition: \(previousState) → \(newState)")
        
        // CRITICAL: Update quota manager with new state
        HybridCreditManager.shared.setUserState(newState)
        
        // If transitioning from anonymous to authenticated, handle quota migration
        if case .anonymous = previousState, case .authenticated(let user) = newState {
            print("🔄 [AUTH] Anonymous → Authenticated transition")
            
            // Initialize new user in backend if needed
            await HybridCreditManager.shared.initializeNewUser()
            
            // Identify user in Adapty for purchase tracking
            do {
                // Mock identify - always succeeds
                // try await AdaptyService.shared.identify(userId: user.id.uuidString)
                print("Mock: User identified in Adapty")
            } catch {
                print("Mock: Adapty identification skipped")
            }
        }
        
        // If transitioning from authenticated to anonymous, handle cleanup
        if case .authenticated = previousState, case .anonymous = newState {
            print("🔄 [AUTH] Authenticated → Anonymous transition")
            
            // Logout from Adapty
            do {
                // Mock logout - always succeeds
                // try await AdaptyService.shared.logout()
                print("Mock: User logged out from Adapty")
            } catch {
                print("Mock: Adapty logout skipped")
            }
        }
    }
    
    // MARK: - Anonymous Authentication
    
    func signInAnonymously() {
        let deviceId = getOrCreateDeviceUUID()
        userState = .anonymous(deviceId: deviceId)
        HybridCreditManager.shared.setUserState(userState)
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
                HybridCreditManager.shared.setUserState(userState)
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
                HybridCreditManager.shared.setUserState(userState)
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
                HybridCreditManager.shared.setUserState(userState)
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
            
            // Switch to anonymous state
            let deviceId = getOrCreateDeviceUUID()
            userState = .anonymous(deviceId: deviceId)
            HybridCreditManager.shared.setUserState(userState)
            
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
        if let existingUUID = UserDefaults.standard.string(forKey: "device_uuid_v1") {
            return existingUUID
        }
        
        let newUUID = UUID().uuidString
        UserDefaults.standard.set(newUUID, forKey: "device_uuid_v1")
        return newUUID
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
