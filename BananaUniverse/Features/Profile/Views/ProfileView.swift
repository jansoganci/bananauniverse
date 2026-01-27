//
//  ProfileView.swift
//  noname_banana
//
//  Created by AI Assistant on 13.10.2025.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var authService = HybridAuthService.shared
    @StateObject private var creditManager = CreditManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showPaywall = false
    @State private var showSignIn = false
    @State private var showAI_Disclosure = false
    @State private var showOnboarding = false
    @State private var authStateRefreshTrigger = false
    @State private var mockNotificationEnabled = true
    @State private var selectedLanguage = "English"
    @State private var selectedNotificationSetting = "Enabled"
    @Environment(\.openURL) var openURL
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Bar
                UnifiedHeaderBar(
                    title: "Profile",
                    leftContent: nil,
                    rightContent: nil
                )
                
                // Main Content
                ScrollView {
                    profileContent
                        .id(authStateRefreshTrigger) // Force refresh when auth state changes
                }
            }
            .background(DesignTokens.Background.primary(colorScheme))
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallPreview()
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .sheet(isPresented: $showAI_Disclosure) {
            AI_Disclosure_View()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(onComplete: {
                showOnboarding = false
            })
        }
        .onReceive(authService.$userState) { newState in
            // Force UI refresh by toggling the trigger
            authStateRefreshTrigger.toggle()
            Task {
                await viewModel.onAuthStateChanged(newState)
            }
        }
        .alert("Restore Purchases", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .alert("Delete Account", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Account", role: .destructive) {
                Task {
                    await viewModel.deleteAccount()
                }
            }
        } message: {
            VStack(spacing: 8) {
                Text("Are you sure you want to delete your account?")
                Text("This action cannot be undone. All your data, including processed images and credits, will be permanently deleted.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var profileContent: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Credit Card
            CreditCard(
                creditsRemaining: creditManager.creditsRemaining,
                features: [
                    "Process AI images",
                    "Fast processing",
                    "High-quality outputs"
                ],
                onBuyCreditsTap: {
                    showPaywall = true
                }
            )
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.top, DesignTokens.Spacing.md)
            
            // Sign In Section (for anonymous users without email)
            if !authService.hasEmail {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    // Section Header
                    Text("Account")
                        .font(DesignTokens.Typography.title3)
                        .foregroundColor(DesignTokens.Text.primary(colorScheme))
                        .padding(.horizontal, DesignTokens.Spacing.md)
                    
                    // Sign In Card
                    Button {
                        showSignIn = true
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                                .frame(width: 32, height: 32)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sign In with Apple")
                                    .font(DesignTokens.Typography.headline)
                                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                                
                                Text("Save your data and sync across devices")
                                    .font(DesignTokens.Typography.caption1)
                                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
                        }
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(DesignTokens.Surface.secondary(colorScheme))
                    .cornerRadius(DesignTokens.CornerRadius.md)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }
            }
            
            // Account Section (for authenticated users with email)
            if authService.hasEmail {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    // Section Header
                    Text("Account")
                        .font(DesignTokens.Typography.title3)
                        .foregroundColor(DesignTokens.Text.primary(colorScheme))
                        .padding(.horizontal, DesignTokens.Spacing.md)
                    
                    // Account Card
                    VStack(spacing: 0) {
                        // Email Row
                        ProfileRow(
                            icon: "envelope.fill",
                            title: "Email",
                            subtitle: authService.currentUser?.email ?? "Unknown",
                            iconColor: DesignTokens.Brand.primary(colorScheme),
                            showChevron: false
                        )
                        
                        Divider()
                            .background(DesignTokens.Surface.secondary(colorScheme))
                            .padding(.leading, 56)
                        
                        // Credits Row
                        ProfileRow(
                            icon: "star.fill",
                            title: "Credits",
                            subtitle: "\(creditManager.creditsRemaining) credits",
                            iconColor: DesignTokens.Brand.primary(colorScheme),
                            showChevron: false,
                            action: {
                                showPaywall = true
                            }
                        )
                        
                        Divider()
                            .background(DesignTokens.Surface.secondary(colorScheme))
                            .padding(.leading, 56)
                        
                        // Sign Out Row
                        ProfileRow(
                            icon: "arrow.right.square",
                            title: "Sign Out",
                            iconColor: DesignTokens.Semantic.warning(colorScheme),
                            showChevron: true,
                            action: {
                                Task {
                                    try? await authService.signOut()
                                }
                            }
                        )
                    }
                    .background(DesignTokens.Surface.secondary(colorScheme))
                    .cornerRadius(DesignTokens.CornerRadius.md)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }
            }
            
            // Settings Section
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Section Header
                Text("Settings")
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                    .padding(.horizontal, DesignTokens.Spacing.md)
                
                // Settings Card
                VStack(spacing: 0) {
                    // Theme Selector
                    HStack(spacing: DesignTokens.Spacing.md) {
                        // Icon with circular background (matching ProfileRow)
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(DesignTokens.Brand.primary(colorScheme).opacity(0.1))
                            )
                        
                        // Text Content (matching ProfileRow)
                        Text("Theme")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Text.primary(colorScheme))
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        // Fixed dropdown picker with proper width and no background
                        Menu {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    themeManager.preference = .light
                                }
                            }) {
                                HStack {
                                    Image(systemName: "sun.max.fill")
                                        .foregroundColor(DesignTokens.Brand.accent(colorScheme))
                                    Text("Light")
                                    if themeManager.preference == .light {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                                    }
                                }
                            }
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    themeManager.preference = .dark
                                }
                            }) {
                                HStack {
                                    Image(systemName: "moon.fill")
                                        .foregroundColor(DesignTokens.Brand.secondary(colorScheme))
                                    Text("Dark")
                                    if themeManager.preference == .dark {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                                    }
                                }
                            }
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    themeManager.preference = .system
                                }
                            }) {
                                HStack {
                                    Image(systemName: "circle.lefthalf.filled")
                                        .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
                                    Text("Auto")
                                    if themeManager.preference == .system {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                // Theme icon
                                Image(systemName: themeManager.preference.icon)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                                
                                Text(themeManager.preference.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(minWidth: 80)
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    
                    Divider()
                        .background(DesignTokens.Surface.secondary(colorScheme))
                        .padding(.leading, 56)
                    
                    // Language Selector
                    HStack(spacing: DesignTokens.Spacing.md) {
                        // Icon with circular background (matching ProfileRow)
                        Image(systemName: "globe")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(DesignTokens.Brand.primary(colorScheme).opacity(0.1))
                            )
                        
                        // Text Content (matching ProfileRow)
                        Text("Language")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Text.primary(colorScheme))
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        // Language dropdown picker
                        Menu {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedLanguage = "English"
                                }
                            }) {
                                HStack {
                                    Text("English")
                                    if selectedLanguage == "English" {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                                    }
                                }
                            }
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedLanguage = "Turkish"
                                }
                            }) {
                                HStack {
                                    Text("Turkish")
                                    if selectedLanguage == "Turkish" {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(selectedLanguage)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(minWidth: 80)
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    
                    Divider()
                        .background(DesignTokens.Surface.secondary(colorScheme))
                        .padding(.leading, 56)
                    
                    // Notifications Selector (DEBUG only - not implemented yet)
                    #if DEBUG
                    HStack(spacing: DesignTokens.Spacing.md) {
                        // Icon with circular background (matching ProfileRow)
                        Image(systemName: "bell.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(DesignTokens.Brand.primary(colorScheme).opacity(0.1))
                            )
                        
                        // Text Content (matching ProfileRow)
                        Text("Notifications")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Text.primary(colorScheme))
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        // Notifications dropdown picker
                        Menu {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedNotificationSetting = "Enabled"
                                    mockNotificationEnabled = true
                                }
                            }) {
                                HStack {
                                    Text("Enabled")
                                    if selectedNotificationSetting == "Enabled" {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                                    }
                                }
                            }
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedNotificationSetting = "Disabled"
                                    mockNotificationEnabled = false
                                }
                            }) {
                                HStack {
                                    Text("Disabled")
                                    if selectedNotificationSetting == "Disabled" {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(selectedNotificationSetting)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(minWidth: 80)
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    
                    Divider()
                        .background(DesignTokens.Surface.secondary(colorScheme))
                        .padding(.leading, 56)
                    #endif
                    
                    // Only show Delete Account for authenticated users
                    if authService.isAuthenticated {
                        Divider()
                            .background(DesignTokens.Surface.secondary(colorScheme))
                            .padding(.leading, 56)
                        
                        Button(action: {
                            if !viewModel.isDeletingAccount {
                                viewModel.showDeleteAccountConfirmation()
                            }
                        }) {
                            HStack(spacing: DesignTokens.Spacing.md) {
                                // Icon with circular background (matching ProfileRow)
                                if viewModel.isDeletingAccount {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 32, height: 32)
                                } else {
                                    Image(systemName: "trash")
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundColor(DesignTokens.Semantic.error(colorScheme))
                                        .frame(width: 32, height: 32)
                                        .background(
                                            Circle()
                                                .fill(DesignTokens.Semantic.error(colorScheme).opacity(0.1))
                                        )
                                }
                                
                                // Text Content (matching ProfileRow)
                                Text(viewModel.isDeletingAccount ? "Deleting Account..." : "Delete Account")
                                    .font(DesignTokens.Typography.body)
                                    .foregroundColor(DesignTokens.Semantic.error(colorScheme))
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.isDeletingAccount)
                    }
                    
                    // Restore Onboarding Button (for testing)
                    #if DEBUG
                    Divider()
                        .background(DesignTokens.Surface.secondary(colorScheme))
                        .padding(.leading, 56)
                    
                    ProfileRow(
                        icon: "arrow.counterclockwise.circle.fill",
                        title: "Restore Onboarding",
                        iconColor: DesignTokens.Brand.secondary(colorScheme),
                        showChevron: true,
                        action: {
                            // Reset the flag and show onboarding immediately
                            UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
                            showOnboarding = true
                            #if DEBUG
                            print("✅ [PROFILE] Onboarding flag reset - showing onboarding now")
                            #endif
                        }
                    )
                    #endif
                }
                .background(DesignTokens.Surface.secondary(colorScheme))
                .cornerRadius(DesignTokens.CornerRadius.md)
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
            
            // Support Section
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Section Header
                Text("Support")
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                    .padding(.horizontal, DesignTokens.Spacing.md)
                
                // Support Card
                VStack(spacing: 0) {
                    ProfileRow(
                        icon: "questionmark.circle.fill",
                        title: "Help & Support",
                        iconColor: DesignTokens.Brand.primary(colorScheme),
                        showChevron: true,
                        action: {
                            if let url = URL(string: Config.supportURL) {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                    
                    Divider()
                        .background(DesignTokens.Surface.secondary(colorScheme))
                        .padding(.leading, 56)
                    
                    ProfileRow(
                        icon: "hand.raised.fill",
                        title: "Privacy Policy",
                        iconColor: DesignTokens.Brand.primary(colorScheme),
                        showChevron: true,
                        action: {
                            if let url = URL(string: Config.privacyPolicyURL) {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                    
                    Divider()
                        .background(DesignTokens.Surface.secondary(colorScheme))
                        .padding(.leading, 56)
                    
                    ProfileRow(
                        icon: "doc.text.fill",
                        title: "Terms of Service",
                        iconColor: DesignTokens.Brand.primary(colorScheme),
                        showChevron: true,
                        action: {
                            if let url = URL(string: Config.termsOfServiceURL) {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                    
                    Divider()
                        .background(DesignTokens.Surface.secondary(colorScheme))
                        .padding(.leading, 56)
                    
                    ProfileRow(
                        icon: "brain.head.profile",
                        title: "AI Service Disclosure",
                        iconColor: DesignTokens.Brand.primary(colorScheme),
                        showChevron: true,
                        action: {
                            showAI_Disclosure = true
                        }
                    )
                    
                    Divider()
                        .background(DesignTokens.Surface.secondary(colorScheme))
                        .padding(.leading, 56)
                    
                    // Restore Purchases Button (always visible)
                    ProfileRow(
                        icon: "arrow.clockwise.circle.fill",
                        title: "Restore Purchases",
                        iconColor: DesignTokens.Brand.primary(colorScheme),
                        showChevron: true,
                        action: {
                            Task {
                                await viewModel.restorePurchases()
                            }
                        }
                    )
                }
                .background(DesignTokens.Surface.secondary(colorScheme))
                .cornerRadius(DesignTokens.CornerRadius.md)
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
            
            // Debug Section (only in debug builds)
            #if DEBUG
            if Config.enablePaymentTestMode {
                PaymentDebugView()
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.md)
            }
            #endif
            
            // Bottom padding for scroll content
            Spacer()
                .frame(height: DesignTokens.Spacing.lg)
        }
    }
}

// MARK: - Credit Card Component
struct CreditCard: View {
    let creditsRemaining: Int
    let features: [String]
    let onBuyCreditsTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Credits")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(DesignTokens.Text.primary(colorScheme))

                    Text("\(creditsRemaining) credit\(creditsRemaining == 1 ? "" : "s") available")
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                }

                Spacer()

                Image(systemName: "star.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DesignTokens.Brand.primary(colorScheme))
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                        Text(feature)
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.Text.primary(colorScheme))
                    }
                }
            }

            Button(action: onBuyCreditsTap) {
                Text("Buy Credits")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Text.onBrand(colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(DesignTokens.Brand.primary(colorScheme))
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(
            DesignTokens.Surface.secondary(colorScheme)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    DesignTokens.Brand.primary(colorScheme).opacity(0.2),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    ProfileView()
        .environmentObject(ThemeManager())
}
