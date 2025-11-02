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
    @StateObject private var creditManager = HybridCreditManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showPaywall = false
    @State private var showSignIn = false
    @State private var showAI_Disclosure = false
    @State private var authStateRefreshTrigger = false
    @State private var mockNotificationEnabled = true
    @Environment(\.openURL) var openURL
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Bar
                UnifiedHeaderBar(
                    title: "Profile",
                    leftContent: nil,
                    rightContent: creditManager.isPremiumUser 
                        ? .unlimitedBadge({})  // PRO badge (non-tappable for MVP)
                        : .getProButton { 
                            showPaywall = true
                            // TODO: Log analytics event - placement: profile_header
                        }
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
            PreviewPaywallView()
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .sheet(isPresented: $showAI_Disclosure) {
            AI_Disclosure_View()
        }
        .onReceive(authService.$userState) { newState in
            // Force UI refresh by toggling the trigger
            authStateRefreshTrigger.toggle()
            Task {
                await viewModel.onAuthStateChanged(newState)
            }
        }
        .onReceive(viewModel.$isPremiumUser) { newValue in
            #if DEBUG
            print("🔄 ProfileView: Premium status changed to \(newValue)")
            #endif
            // UI will automatically update due to @Published property
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
            // Pro Card
            ProCard(
                isProActive: viewModel.isPremiumUser,
                features: [
                    "Unlimited edits",
                    "Fast processing",
                    "No watermark"
                ],
                subscriptionStatusText: viewModel.getSubscriptionStatusText(),
                isLoadingSubscription: viewModel.isLoadingSubscription,
                onUpgradeTap: {
                    showPaywall = true
                    // TODO: insert Adapty Paywall ID here - placement: profile_upgrade
                },
                onManageTap: {
                    viewModel.openManageSubscription()
                },
                onRefreshTap: {
                    Task {
                        await viewModel.refreshSubscriptionDetails()
                    }
                }
            )
            .padding(.horizontal, DesignTokens.Spacing.md)
            
            // Premium Status Banner (for premium users)
            if viewModel.isPremiumUser {
                PremiumStatusBanner()
                    .padding(.horizontal, DesignTokens.Spacing.md)
            }
            
            // Sign In or Create Account Button (for anonymous users)
            if !authService.isAuthenticated {
                Button {
                    showSignIn = true
                } label: {
                    HStack {
                        Image(systemName: "person.circle")
                            .font(.system(size: 18, weight: .medium))
                        Text("Sign In or Create Account")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DesignTokens.Brand.primary(colorScheme))
                    .cornerRadius(12)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
            
            // Account Section (for authenticated users)
            if authService.isAuthenticated {
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
                        
                        // Quota Display
                        QuotaDisplayView(style: .detailed)
                        
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
                    HStack(spacing: 16) {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 20))
                            .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Theme")
                                .font(.system(size: 16))
                                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                            
                            // Show subtitle only for Auto mode
                            if themeManager.preference == .system {
                                Text("(Follow System)")
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                            }
                        }
                        
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
                                        .foregroundColor(.orange)
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
                                        .foregroundColor(.blue)
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
                                        .foregroundColor(.gray)
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
                    .frame(height: 50)
                    
                    Divider()
                        .background(DesignTokens.Surface.secondary(colorScheme))
                        .padding(.leading, 56)
                    
                    // Language Row
                    ProfileRow(
                        icon: "globe",
                        title: "Language",
                        subtitle: "English",
                        iconColor: DesignTokens.Brand.primary(colorScheme),
                        showChevron: true,
                        action: {
                            // Mock action
                            print("Language settings tapped")
                        }
                    )
                    
                    Divider()
                        .background(DesignTokens.Surface.secondary(colorScheme))
                        .padding(.leading, 56)
                    
                    // Notifications Row
                    ProfileRow(
                        icon: "bell.fill",
                        title: "Notifications",
                        subtitle: mockNotificationEnabled ? "Enabled" : "Disabled",
                        iconColor: DesignTokens.Brand.secondary(colorScheme),
                        showChevron: true,
                        action: {
                            // Mock toggle
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mockNotificationEnabled.toggle()
                            }
                        }
                    )
                    
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
                            HStack(spacing: 16) {
                                if viewModel.isDeletingAccount {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 24, height: 24)
                                } else {
                                    Image(systemName: "trash")
                                        .font(.system(size: 20))
                                        .foregroundColor(DesignTokens.Semantic.error(colorScheme))
                                        .frame(width: 24)
                                }
                                
                                Text(viewModel.isDeletingAccount ? "Deleting Account..." : "Delete Account")
                                    .font(.system(size: 16))
                                    .foregroundColor(DesignTokens.Semantic.error(colorScheme))
                                
                                Spacer()
                            }
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .frame(height: 50)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.isDeletingAccount)
                    }
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
                        iconColor: DesignTokens.Brand.secondary(colorScheme),
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
                        iconColor: DesignTokens.Brand.accent(colorScheme),
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
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
}

// MARK: - Pro Card Component
struct ProCard: View {
    let isProActive: Bool
    let features: [String]
    let subscriptionStatusText: String
    let isLoadingSubscription: Bool
    let onUpgradeTap: () -> Void
    let onManageTap: () -> Void
    let onRefreshTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isProActive ? "Unlimited Mode" : "Upgrade to Pro")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(colorScheme == .light ? Color(hex: "1A1A1A") : .white)

                    Text(isProActive ? "You have unlimited access" : "Get unlimited edits")
                        .font(.system(size: 14))
                        .foregroundColor(colorScheme == .light ? Color(hex: "1A1A1A").opacity(0.7) : .white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "crown.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DesignTokens.Brand.primary(colorScheme))
            }

            if !isProActive {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(colorScheme == .light ? Color(hex: "00E5FF") : DesignTokens.Brand.secondary(colorScheme))
                            Text(feature)
                                .font(.system(size: 14))
                                .foregroundColor(colorScheme == .light ? Color(hex: "1A1A1A").opacity(0.8) : .white.opacity(0.9))
                        }
                    }
                }

                Button(action: onUpgradeTap) {
                    Text("Upgrade Now")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "FFFFFF"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color(hex: "6B21C0"))
                        .cornerRadius(12)
                }
            } else {
                Button(action: onManageTap) {
                    Text("Manage Subscription")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colorScheme == .light ? Color(hex: "6B21C0") : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(colorScheme == .light ? Color(hex: "6B21C0").opacity(0.1) : Color.white.opacity(0.2))
                        .cornerRadius(12)
                }

                // Subscription Status Display
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(subscriptionStatusText)
                            .font(.system(size: 14))
                            .foregroundColor(colorScheme == .light ? Color(hex: "1A1A1A").opacity(0.6) : .white.opacity(0.8))
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Button(action: onRefreshTap) {
                            if isLoadingSubscription {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .light ? Color(hex: "6B21C0") : .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14))
                                    .foregroundColor(colorScheme == .light ? Color(hex: "1A1A1A").opacity(0.5) : .white.opacity(0.6))
                            }
                        }
                        .disabled(isLoadingSubscription)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: colorScheme == .light
                    ? [Color(hex: "EDEBFF"), Color(hex: "FFFFFF")]
                    : [DesignTokens.Brand.purple, DesignTokens.Brand.primary(colorScheme)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    colorScheme == .light
                        ? Color(hex: "9D7FD6").opacity(0.25)
                        : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Premium Status Banner Component
struct PremiumStatusBanner: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 16))
                .foregroundColor(DesignTokens.Brand.primary(colorScheme))
            
            Text("You're Premium! Enjoy unlimited access.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.Brand.primary(colorScheme).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignTokens.Brand.primary(colorScheme).opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ProfileView()
        .environmentObject(ThemeManager())
}
