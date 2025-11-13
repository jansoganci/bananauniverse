//
//  QuickAuthView.swift
//  noname_banana
//
//  Created by AI Assistant on 14.10.2025.
//

import SwiftUI
import AuthenticationServices
import CryptoKit

/// Quick authentication view shown during purchase flow
struct QuickAuthView: View {
    @StateObject private var authService = HybridAuthService.shared
    @StateObject private var creditManager = CreditManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var currentNonce: String? = nil
    
    @Environment(\.dismiss) var dismiss
    
    var onAuthSuccess: () -> Void
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && isValidEmail(email)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 50))
                            .foregroundColor(DesignTokens.Brand.primary(.light))
                        
                        Text("Sync Your Progress")
                            .font(.title)
                            .bold()
                            .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                        
                        Text("Sign in to sync your work across all your devices and never lose your creations")
                            .font(.subheadline)
                            .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // Benefits
                    VStack(alignment: .leading, spacing: 16) {
                        BenefitRow(icon: "checkmark.icloud", text: "Sync across iPhone, iPad, and future devices")
                        BenefitRow(icon: "arrow.clockwise", text: "Automatic backup and restore")
                        BenefitRow(icon: "gift", text: "Get started with free credits")
                        BenefitRow(icon: "lock.shield", text: "Secure and private - your data stays protected")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    // Social Sign-In (Primary options)
                    VStack(spacing: 12) {
                        // Apple Sign In
                        SignInWithAppleButton(
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                                let raw = NonceGenerator.generate()
                                self.currentNonce = raw
                                request.nonce = NonceGenerator.sha256(raw)
                            },
                            onCompletion: { result in
                                handleAppleSignIn(result)
                            }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                        Text("or")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .padding(.horizontal)
                    
                    // Email Sign-In
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .textFieldStyle(.roundedBorder)
                        
                        SecureField("Password", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(action: handleEmailAuth) {
                            if authService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid ? DesignTokens.Brand.primary(.light) : DesignTokens.Brand.primary(.light).opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(!isFormValid || authService.isLoading)
                        
                        Button(action: { isSignUp.toggle() }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "New here? Create Account")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Authentication Handlers
    
    private func handleEmailAuth() {
        Task {
            do {
                if isSignUp {
                    try await authService.signUp(email: email, password: password)
                } else {
                    try await authService.signIn(email: email, password: password)
                }
                
                // Migrate anonymous credits
                // Migration is handled automatically by HybridAuthService
                
                dismiss()
                onAuthSuccess()
                
            } catch {
                let appError = AppError.from(error)
                errorMessage = appError.errorDescription ?? "Authentication failed"
                showError = true
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            do {
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let tokenData = credential.identityToken,
                          let idToken = String(data: tokenData, encoding: .utf8) else {
                        errorMessage = HybridAuthError.invalidAppleCredential.errorDescription ?? "Apple Sign-In failed"
                        showError = true
                        return
                    }
                    let nonce = currentNonce
                    try await authService.signInWithApple(idToken: idToken, nonce: nonce)
                    
                    dismiss()
                    onAuthSuccess()
                    
                case .failure(let error):
                    let appError = AppError.from(error)
                    errorMessage = appError.errorDescription ?? "Apple Sign-In failed"
                    showError = true
                }
            } catch {
                let appError = AppError.from(error)
                errorMessage = appError.errorDescription ?? "Apple Sign-In failed"
                showError = true
            }
        }
    }
    
    // MARK: - Nonce Utilities
    enum NonceGenerator {
        static func generate(length: Int = 32) -> String {
            let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
            var result = ""
            var remainingLength = length
            while remainingLength > 0 {
                let randoms: [UInt8] = (0..<16).map { _ in UInt8.random(in: 0...255) }
                randoms.forEach { random in
                    if remainingLength == 0 { return }
                    if random < charset.count {
                        result.append(charset[Int(random)])
                        remainingLength -= 1
                    }
                }
            }
            return result
        }
        
        static func sha256(_ input: String) -> String {
            guard let data = input.data(using: .utf8) else { return input }
            let hashed = SHA256.hash(data: data)
            return hashed.compactMap { String(format: "%02x", $0) }.joined()
        }
    }
}

// MARK: - Benefit Row Component

struct BenefitRow: View {
    let icon: String
    let text: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(DesignTokens.Brand.primary(.light))
                .font(.system(size: 20))
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    QuickAuthView(onAuthSuccess: {
    })
}

