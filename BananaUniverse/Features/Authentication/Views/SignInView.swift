//
//  SignInView.swift
//  noname_banana
//
//  Created by AI Assistant on 14.10.2025.
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct SignInView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authService = HybridAuthService.shared
    @StateObject private var creditManager = CreditManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
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
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(isSignUp ? "auth_create_account".localized : "auth_sign_in".localized)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                    
                    Text("auth_sync_devices".localized)
                        .font(.system(size: 16))
                        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                }
                .padding(.top, 40)
                
                // Value Proposition
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up")
                            .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                        Text("auth_never_lose_work".localized)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                    }
                    
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                        Text("auth_secure_backup".localized)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                // Sign In Form
                VStack(spacing: 16) {
                    TextField("auth_email".localized, text: $email)
                        .textFieldStyle(CustomTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                    
                    SecureField(isSignUp ? "auth_create_password".localized : "auth_password".localized, text: $password)
                        .textFieldStyle(CustomTextFieldStyle())
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.Semantic.error(themeManager.resolvedColorScheme))
                            .padding(.horizontal, 20)
                    }
                    
                    // Sign In/Up Button
                    Button(action: {
                        Task {
                            await handleEmailAuth()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Text.onBrand(themeManager.resolvedColorScheme)))
                                    .scaleEffect(0.8)
                            }
                            Text(isSignUp ? "auth_create_account".localized : "auth_sign_in".localized)
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(DesignTokens.Text.onBrand(themeManager.resolvedColorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isFormValid ? DesignTokens.Brand.primary(themeManager.resolvedColorScheme) : DesignTokens.Brand.primary(themeManager.resolvedColorScheme).opacity(0.6))
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || isLoading)
                    .padding(.horizontal, 20)
                    
                    // Toggle Sign Up/Sign In
                    Button(action: {
                        isSignUp.toggle()
                        errorMessage = ""
                    }) {
                        Text(isSignUp ? "auth_already_have_account".localized : "auth_dont_have_account".localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                            .underline()
                    }
                }
                
                // Divider
                HStack {
                    Rectangle()
                        .fill(DesignTokens.Text.tertiary(themeManager.resolvedColorScheme))
                        .frame(height: 1)
                    Text("auth_or".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                        .padding(.horizontal, 16)
                    Rectangle()
                        .fill(DesignTokens.Text.tertiary(themeManager.resolvedColorScheme))
                        .frame(height: 1)
                }
                .padding(.horizontal, 20)
                
                // Apple Sign In
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                        
                        // Generate and attach nonce for replay protection
                        let rawNonce = NonceGenerator.generate()
                        self.currentNonce = rawNonce
                        request.nonce = NonceGenerator.sha256(rawNonce)
                    },
                    onCompletion: { result in
                        Task {
                            await handleAppleSignIn(result)
                        }
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignTokens.Text.tertiary(themeManager.resolvedColorScheme), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("auth_cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                }
            }
        }
    }
    
    private func handleEmailAuth() async {
        isLoading = true
        errorMessage = ""
        
        do {
            if isSignUp {
                try await authService.signUp(email: email, password: password)
            } else {
                try await authService.signIn(email: email, password: password)
            }
            
            // Migration will happen automatically in HybridAuthService
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            dismiss()
        } catch {
            let appError = AppError.from(error)
            errorMessage = appError.errorDescription ?? "Sign in failed"
        }
        
        isLoading = false
    }
    
    @State private var currentNonce: String? = nil
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = ""
        
        do {
            switch result {
            case .success(let authorization):
                
                guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    throw HybridAuthError.invalidAppleCredential
                }
                
                
                guard let identityTokenData = appleIDCredential.identityToken else {
                    throw HybridAuthError.invalidAppleCredential
                }
                
                
                guard let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                    throw HybridAuthError.invalidAppleCredential
                }
                
                
                let nonce = currentNonce
                
                try await authService.signInWithApple(idToken: identityToken, nonce: nonce)
                
                // Wait for state to propagate before dismissing
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                
                dismiss()
                
            case .failure(let error):
                
                let appError = AppError.from(error)
                errorMessage = appError.errorDescription ?? "Apple Sign-In failed"
            }
        } catch {
            let appError = AppError.from(error)
            errorMessage = appError.errorDescription ?? "Apple Sign-In failed"
        }
        
        isLoading = false
    }
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    @EnvironmentObject var themeManager: ThemeManager
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(12)
            .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DesignTokens.Text.tertiary(themeManager.resolvedColorScheme), lineWidth: 1)
            )
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

#Preview {
    SignInView()
}
