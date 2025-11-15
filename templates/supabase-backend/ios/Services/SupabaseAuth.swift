/**
 * Supabase Auth Service
 * Purpose: Handle authentication with Supabase (Apple Sign-In, Email/Password)
 *
 * Usage:
 * let auth = SupabaseAuth.shared
 * try await auth.signInWithApple()
 * try await auth.signInWithEmail("user@example.com", password: "pass123")
 */

import Foundation
import Supabase
import AuthenticationServices

@MainActor
class SupabaseAuth: ObservableObject {
    static let shared = SupabaseAuth()

    @Published var isAuthenticated = false
    @Published var currentUser: User?

    private let supabase: SupabaseClient

    private init() {
        // Initialize Supabase client
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "")!,
            supabaseKey: ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
        )

        // Check if user is already logged in
        Task {
            await checkAuthState()
        }
    }

    // MARK: - Auth State

    func checkAuthState() async {
        do {
            let user = try await supabase.auth.session.user
            self.currentUser = user
            self.isAuthenticated = true
        } catch {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }

    // MARK: - Apple Sign-In

    func signInWithApple() async throws {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.email, .fullName]

        let authController = ASAuthorizationController(authorizationRequests: [request])

        // Handle Apple Sign-In response
        // Note: In production, implement proper delegate pattern
        // For template simplicity, assume we get the token

        let idToken = "apple_id_token" // TODO: Get from Apple delegate

        try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken
            )
        )

        await checkAuthState()
    }

    // MARK: - Email/Password Auth

    func signUp(email: String, password: String) async throws {
        try await supabase.auth.signUp(
            email: email,
            password: password
        )

        // User will receive verification email
        print("Check your email to verify your account")
    }

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(
            email: email,
            password: password
        )

        await checkAuthState()
    }

    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
        print("Check your email for password reset link")
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await supabase.auth.signOut()
        self.currentUser = nil
        self.isAuthenticated = false
    }

    // MARK: - Access Token

    func getAccessToken() async throws -> String {
        guard let session = try? await supabase.auth.session else {
            throw AuthError.notAuthenticated
        }
        return session.accessToken
    }

    // MARK: - Guest Mode (Device-based)

    func createGuestAccount(deviceId: String) async throws {
        // Call your backend to create guest user
        let url = URL(string: "\(supabase.supabaseURL)/functions/v1/create-guest")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["device_id": deviceId])

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GuestResponse.self, from: data)

        // Store guest token
        // In production, use Keychain
        UserDefaults.standard.set(response.token, forKey: "guest_token")
    }
}

// MARK: - Models

enum AuthError: Error {
    case notAuthenticated
    case invalidToken
}

struct GuestResponse: Codable {
    let token: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case token
        case userId = "user_id"
    }
}
