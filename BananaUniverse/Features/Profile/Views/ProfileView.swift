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
    @StateObject private var languageManager = LanguageManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showPaywall = false
    @State private var showSignIn = false
    @State private var showAI_Disclosure = false
    @State private var showOnboarding = false
    @State private var authStateRefreshTrigger = false
    @State private var mockNotificationEnabled = true
    @State private var selectedNotificationSetting = "Enabled"
    @Environment(\.openURL) var openURL
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Bar
                UnifiedHeaderBar(
                    title: "profile_title".localized,
                    leftContent: nil,
                    rightContent: nil
                )
                
                // Main Content
                ScrollView {
                    profileContent
                        .id(authStateRefreshTrigger) // Force refresh when auth state changes
                        .id(languageManager.currentLanguage) // Force refresh when language changes
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
        .alert("profile_restore_purchases".localized, isPresented: $viewModel.showAlert) {
            Button("common_ok".localized, role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .alert("profile_delete_account".localized, isPresented: $viewModel.showDeleteConfirmation) {
            Button("common_cancel".localized, role: .cancel) { }
            Button("profile_delete_account".localized, role: .destructive) {
                Task {
                    await viewModel.deleteAccount()
                }
            }
        } message: {
            VStack(spacing: 8) {
                Text("profile_delete_account_confirm".localized)
                Text("profile_delete_account_warning".localized)
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
                    "image_processing_status_creating".localized,
                    "paywall_benefit_2_title".localized,
                    "paywall_benefit_3_title".localized
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
                    Text("profile_account_section".localized)
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
                                Text("profile_sign_in_apple".localized)
                                    .font(DesignTokens.Typography.headline)
                                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                                
                                Text("profile_sync_data".localized)
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
                    Text("profile_account_section".localized)
                        .font(DesignTokens.Typography.title3)
                        .foregroundColor(DesignTokens.Text.primary(colorScheme))
                        .padding(.horizontal, DesignTokens.Spacing.md)
                    
                    // Account Card
                    VStack(spacing: 0) {
                        // Email Row
                        ProfileRow(
                            icon: "envelope.fill",
                            title: "profile_email".localized,
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
                            title: "profile_credits".localized,
                            subtitle: creditManager.creditsRemaining == 1 ? "home_credit_remaining".localized(creditManager.creditsRemaining) : "home_credits_remaining".localized(creditManager.creditsRemaining),
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
                            title: "profile_sign_out".localized,
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
                Text("profile_settings_section".localized)
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
                        Text("profile_theme".localized)
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
                                    Text("profile_theme_light".localized)
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
                                    Text("profile_theme_dark".localized)
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
                                    Text("profile_theme_auto".localized)
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
                        Text("profile_language".localized)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Text.primary(colorScheme))
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        // Language dropdown picker
                        Menu {
                            ForEach(AppLanguage.allCases) { language in
                                Button(action: {
                                    languageManager.setLanguage(language.rawValue)
                                }) {
                                    HStack {
                                        Text(language.displayName)
                                        if languageManager.currentLanguage == language.rawValue {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                                .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(AppLanguage(rawValue: languageManager.currentLanguage)?.displayName ?? "English")
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
                        Text("profile_notifications".localized)
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
                                    Text("profile_notifications_enabled".localized)
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
                                    Text("profile_notifications_disabled".localized)
                                    if selectedNotificationSetting == "Disabled" {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(selectedNotificationSetting == "Enabled" ? "profile_notifications_enabled".localized : "profile_notifications_disabled".localized)
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
                                Text(viewModel.isDeletingAccount ? "profile_deleting_account".localized : "profile_delete_account".localized)
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
                        icon: "arrow.clockwise",
                        title: "profile_restore_onboarding".localized,
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
                Text("profile_support_section".localized)
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                    .padding(.horizontal, DesignTokens.Spacing.md)
                
                // Support Card
                VStack(spacing: 0) {
                    ProfileRow(
                        icon: "questionmark.circle.fill",
                        title: "profile_help_support".localized,
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
                        title: "profile_privacy_policy".localized,
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
                        title: "profile_terms_service".localized,
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
                        title: "profile_ai_disclosure".localized,
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
                        title: "profile_restore_purchases".localized,
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
            PaymentDebugView()
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.md)
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
                    Text("profile_credits_title".localized)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(DesignTokens.Text.primary(colorScheme))

                    Text(creditsRemaining == 1 ? "profile_credit_available".localized(creditsRemaining) : "profile_credits_available".localized(creditsRemaining))
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
                Text("profile_buy_credits".localized)
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
