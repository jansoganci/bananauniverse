//
//  ProfilePreview.swift
//  BananaUniverse
//
//  PREVIEW ONLY - Modern Apple HIG-compliant Profile screen design
//  Does not affect the actual app. Safe to preview in Xcode.
//
//  Design Philosophy:
//  - Clean, grouped layout with subtle rounded cards
//  - SF Symbols for visual clarity
//  - 8pt grid spacing system
//  - Theme-aware (light/dark mode)
//

import SwiftUI

// MARK: - Preview: Modern Profile Screen Structure
struct ProfilePreview: View {
    @Environment(\.colorScheme) var systemColorScheme
    @StateObject private var themeManager = ThemeManager()
    
    // Mock user data
    @State private var mockUsername = "Jan Söğancı"
    @State private var mockEmail = "jan@example.com"
    @State private var mockThemePreference = ThemePreference.system
    @State private var mockNotificationEnabled = true
    
    private var colorScheme: ColorScheme {
        themeManager.resolvedColorScheme
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fixed Header
                headerView
                
                // Scrollable Content
                contentView
            }
            .background(DesignTokens.Background.primary(colorScheme))
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
        .environmentObject(themeManager)
        .onAppear {
            themeManager.updateResolvedScheme(systemScheme: systemColorScheme)
        }
        .onChange(of: systemColorScheme) { newScheme in
            themeManager.updateResolvedScheme(systemScheme: newScheme)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Spacer()
            
            Text("Profile")
                .font(DesignTokens.Typography.title2)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: DesignTokens.Layout.headerHeight)
        .background(DesignTokens.Surface.primary(colorScheme))
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                // Account Section
                accountSection
                    .padding(.top, DesignTokens.Spacing.md)
                
                // Settings Section
                settingsSection
                
                // Support Section
                supportSection
                
                // Bottom padding
                Spacer()
                    .frame(height: DesignTokens.Spacing.xl)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Section Header
            Text("Account")
                .font(DesignTokens.Typography.title3)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
            
            // Account Card
            VStack(spacing: 0) {
                // Username Row
                ProfileRow(
                    icon: "person.circle.fill",
                    title: "Username",
                    subtitle: mockUsername,
                    showChevron: false
                )
                
                Divider()
                    .background(DesignTokens.Surface.secondary(colorScheme))
                    .padding(.leading, 56)
                
                // Email Row
                ProfileRow(
                    icon: "envelope.fill",
                    title: "Email",
                    subtitle: mockEmail,
                    showChevron: false
                )
                
            }
            .background(DesignTokens.Surface.secondary(colorScheme))
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Section Header
            Text("Settings")
                .font(DesignTokens.Typography.title3)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
            
            // Settings Card
            VStack(spacing: 0) {
                // Theme Toggle
                ProfileRow(
                    icon: "paintbrush.fill",
                    title: "Theme",
                    subtitle: mockThemePreference.displayName,
                    iconColor: DesignTokens.Brand.primary(colorScheme),
                    showChevron: true,
                    action: {
                        // Mock action - cycle through themes
                        withAnimation(.easeInOut(duration: 0.2)) {
                            switch mockThemePreference {
                            case .light:
                                mockThemePreference = .dark
                            case .dark:
                                mockThemePreference = .system
                            case .system:
                                mockThemePreference = .light
                            }
                        }
                    }
                )
                
                Divider()
                    .background(DesignTokens.Surface.secondary(colorScheme))
                    .padding(.leading, 56)
                
                // Language
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
                
                // Notifications Toggle
                ProfileRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: mockNotificationEnabled ? "Enabled" : "Disabled",
                    iconColor: DesignTokens.Brand.secondary(colorScheme),
                    showChevron: true,
                    action: {
                        // Mock action - toggle notifications
                        withAnimation(.easeInOut(duration: 0.2)) {
                            mockNotificationEnabled.toggle()
                        }
                    }
                )
            }
            .background(DesignTokens.Surface.secondary(colorScheme))
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
    }
    
    // MARK: - Support Section
    
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Section Header
            Text("Support")
                .font(DesignTokens.Typography.title3)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
            
            // Support Card
            VStack(spacing: 0) {
                // Help & Support
                ProfileRow(
                    icon: "questionmark.circle.fill",
                    title: "Help & Support",
                    iconColor: DesignTokens.Brand.primary(colorScheme),
                    showChevron: true,
                    action: {
                        // Mock action
                        print("Help & Support tapped")
                    }
                )
                
                Divider()
                    .background(DesignTokens.Surface.secondary(colorScheme))
                    .padding(.leading, 56)
                
                // Privacy Policy
                ProfileRow(
                    icon: "hand.raised.fill",
                    title: "Privacy Policy",
                    iconColor: DesignTokens.Brand.primary(colorScheme),
                    showChevron: true,
                    action: {
                        // Mock action
                        print("Privacy Policy tapped")
                    }
                )
                
                Divider()
                    .background(DesignTokens.Surface.secondary(colorScheme))
                    .padding(.leading, 56)
                
                // Terms of Service
                ProfileRow(
                    icon: "doc.text.fill",
                    title: "Terms of Service",
                    iconColor: DesignTokens.Brand.primary(colorScheme),
                    showChevron: true,
                    action: {
                        // Mock action
                        print("Terms of Service tapped")
                    }
                )
                
                Divider()
                    .background(DesignTokens.Surface.secondary(colorScheme))
                    .padding(.leading, 56)
                
                // AI Service Disclosure
                ProfileRow(
                    icon: "brain.head.profile",
                    title: "AI Service Disclosure",
                    iconColor: DesignTokens.Brand.secondary(colorScheme),
                    showChevron: true,
                    action: {
                        // Mock action
                        print("AI Service Disclosure tapped")
                    }
                )
                
                Divider()
                    .background(DesignTokens.Surface.secondary(colorScheme))
                    .padding(.leading, 56)
                
                // Restore Purchases
                ProfileRow(
                    icon: "arrow.clockwise.circle.fill",
                    title: "Restore Purchases",
                    iconColor: DesignTokens.Brand.accent(colorScheme),
                    showChevron: true,
                    action: {
                        // Mock action
                        print("Restore Purchases tapped")
                    }
                )
            }
            .background(DesignTokens.Surface.secondary(colorScheme))
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
    }
}

// MARK: - Xcode Preview

#Preview("Profile Preview - Light") {
    ProfilePreview()
        .preferredColorScheme(.light)
}

#Preview("Profile Preview - Dark") {
    ProfilePreview()
        .preferredColorScheme(.dark)
}


