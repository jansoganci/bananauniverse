//
//  AI_Disclosure_View.swift
//  BananaUniverse
//
//  Created by AI Assistant on December 2024.
//  Apple-compliant AI service disclosure screen
//
//  INTEGRATION SUGGESTIONS:
//  - Currently accessible via Profile > Settings > "AI Service Disclosure"
//  - Consider adding to onboarding flow after Terms acceptance
//  - Could be shown in paywall before purchase confirmation
//  - May be required in first-time user experience for Apple compliance
//

import SwiftUI

struct AI_Disclosure_View: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Section
                    headerSection
                    
                    // Main Content
                    contentSection
                    
                    // AI Services Section
                    aiServicesSection
                    
                    // Privacy Policy Section
                    privacyPolicySection
                    
                    // Footer
                    footerSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
            .navigationTitle("AI Disclosure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.Brand.accent(themeManager.resolvedColorScheme))
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(DesignTokens.Brand.accent(themeManager.resolvedColorScheme))
                
                Text("AI Service Disclosure")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                
                Spacer()
            }
            
            Text("Transparency about our AI-powered features")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How We Use AI")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("BananaUniverse uses AI-powered services to enhance your image editing experience. These services process your images and prompts securely in the cloud.")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                
                Text("We do not store your data permanently and respect your privacy throughout the entire process.")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignTokens.Surface.primary(themeManager.resolvedColorScheme))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - AI Services Section
    
    private var aiServicesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Services Used")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
            
            VStack(alignment: .leading, spacing: 16) {
                // FalClient API
                aiServiceRow(
                    icon: "wand.and.rays",
                    title: "FalClient API",
                    description: "AI image editing and enhancement",
                    color: DesignTokens.Brand.accent(themeManager.resolvedColorScheme)
                )
                
                // OpenAI/Gemini APIs
                aiServiceRow(
                    icon: "text.bubble",
                    title: "OpenAI / Gemini APIs",
                    description: "Text and prompt generation",
                    color: DesignTokens.Brand.secondary(themeManager.resolvedColorScheme)
                )
                
                // Local Processing
                aiServiceRow(
                    icon: "cpu",
                    title: "Local Processing",
                    description: "Offline image optimizations",
                    color: DesignTokens.Brand.primary(.light)
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignTokens.Surface.primary(themeManager.resolvedColorScheme))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Privacy Policy Section
    
    private var privacyPolicySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy & Data Protection")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Your privacy is important to us. Learn more about how we handle your data and protect your information.")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                
                Button(action: {
                    if let url = URL(string: Config.privacyPolicyURL) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 18, weight: .medium))
                        
                        Text("View Privacy Policy")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                DesignTokens.Brand.accent(themeManager.resolvedColorScheme),
                                DesignTokens.Brand.accent(themeManager.resolvedColorScheme).opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: DesignTokens.Brand.accent(themeManager.resolvedColorScheme).opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignTokens.Surface.primary(themeManager.resolvedColorScheme))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            Text("Questions about our AI services?")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
            
            Button(action: {
                if let url = URL(string: Config.supportURL) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Contact Support")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Brand.accent(themeManager.resolvedColorScheme))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignTokens.Brand.accent(themeManager.resolvedColorScheme), lineWidth: 1.5)
                    )
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 40)
    }
    
    // MARK: - Helper Methods
    
    private func aiServiceRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("Light Mode") {
    AI_Disclosure_View()
        .environmentObject(ThemeManager())
}

#Preview("Dark Mode") {
    AI_Disclosure_View()
        .environmentObject(ThemeManager())
        .preferredColorScheme(.dark)
}
