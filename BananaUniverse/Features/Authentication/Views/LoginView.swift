//
//  LoginView.swift
//  noname_banana
//
//  Created by AI Assistant on 13.10.2025.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authService = HybridAuthService.shared
    @EnvironmentObject var themeManager: ThemeManager
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
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
        VStack(spacing: 24) {
            Text(isSignUpMode ? "Create Account" : "Welcome Back")
                .font(.largeTitle)
                .bold()
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
            
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Button(action: handleAuth) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isSignUpMode ? "Sign Up" : "Sign In")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isFormValid ? DesignTokens.Brand.primary(themeManager.resolvedColorScheme) : DesignTokens.Brand.primary(themeManager.resolvedColorScheme).opacity(0.6))
                .foregroundColor(DesignTokens.Text.onBrand(themeManager.resolvedColorScheme))
                .cornerRadius(10)
            }
            .disabled(!isFormValid || authService.isLoading)
            
            Button(isSignUpMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                isSignUpMode.toggle()
                clearForm()
            }
            .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
            
            Spacer()
        }
        .padding()
        .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
        .alert("Authentication Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: authService.errorMessage) { errorMessage in
            if let errorMessage = errorMessage {
                alertMessage = errorMessage
                showingAlert = true
                authService.clearError()
            }
        }
    }
    
    private func handleAuth() {
        Task {
            do {
                if isSignUpMode {
                    try await authService.signUp(email: email, password: password)
                } else {
                    try await authService.signIn(email: email, password: password)
                }
            } catch {
                let appError = AppError.from(error)
                alertMessage = appError.errorDescription ?? "Login failed"
                showingAlert = true
            }
        }
    }
    
    private func clearForm() {
        email = ""
        password = ""
        authService.clearError()
    }
}

#Preview {
    LoginView()
}
