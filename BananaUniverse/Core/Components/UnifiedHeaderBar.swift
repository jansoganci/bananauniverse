//
//  UnifiedHeaderBar.swift
//  BananaUniverse
//
//  Created by AI Assistant on 14.10.2025.
//

import SwiftUI

// MARK: - Unified Header Bar Component
struct UnifiedHeaderBar: View {
    let title: String
    let leftContent: HeaderContent?
    let rightContent: HeaderContent?
    
    @EnvironmentObject var themeManager: ThemeManager
    
    init(
        title: String,
        leftContent: HeaderContent? = nil,
        rightContent: HeaderContent? = nil
    ) {
        self.title = title
        self.leftContent = leftContent
        self.rightContent = rightContent
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Left Content
            if let left = leftContent {
                headerContentView(left)
            }
            
            // Center Title
            Spacer()
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                Spacer()
            }
            
            // Right Content
            if let right = rightContent {
                headerContentView(right)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.top, DesignTokens.Spacing.sm)
        .frame(height: DesignTokens.Layout.headerHeight)
        .background(DesignTokens.Surface.primary(themeManager.resolvedColorScheme))
        .designShadow(DesignTokens.Shadow.sm)
    }
    
    @ViewBuilder
    private func headerContentView(_ content: HeaderContent) -> some View {
        switch content {
        case .brandLogo(let brandName):
            HStack(spacing: 6) {
                Text("🍌")
                    .font(.system(size: 18))
                
                Text(brandName)
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
            }
            
        case .appLogo(let size):
            AppLogo(size: size)
            
        case .getProButton(let action):
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                    Text("Get PRO")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(DesignTokens.Surface.primary(themeManager.resolvedColorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(DesignTokens.Brand.primary(themeManager.resolvedColorScheme), lineWidth: 1)
                        )
                        .designShadow(DesignTokens.Shadow.sm)
                )
            }
            
        case .quotaBadge(_, _, let action):
            QuotaDisplayView(style: .compact, action: action)
            
        case .unlimitedBadge(let action):
            QuotaDisplayView(style: .compact, action: action)
            
        case .empty:
            EmptyView()
        }
    }
}

// MARK: - Header Content Types
enum HeaderContent {
    case brandLogo(String)
    case appLogo(CGFloat)
    case getProButton(() -> Void)
    case quotaBadge(Int, Int, () -> Void) // quota, limit, action
    case unlimitedBadge(() -> Void)
    case empty
}

#Preview {
    VStack(spacing: 0) {
        // Home style
        UnifiedHeaderBar(
            title: "Banana Universe",
            leftContent: .brandLogo("Banana Universe"),
            rightContent: .getProButton({})
        )
        
        // Chat style - Free user
        UnifiedHeaderBar(
            title: "Banana Universe",
            leftContent: .brandLogo("Banana Universe"),
            rightContent: .quotaBadge(0, 3, {})
        )
        
        // Chat style - Unlimited mode with App Logo
        UnifiedHeaderBar(
            title: "",
            leftContent: .appLogo(32),
            rightContent: .unlimitedBadge({})
        )
        
        // Library/Profile style
        UnifiedHeaderBar(
            title: "History",
            leftContent: nil,
            rightContent: nil
        )
    }
}

