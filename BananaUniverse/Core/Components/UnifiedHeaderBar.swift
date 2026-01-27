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
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Left Content
            if let left = leftContent {
                headerContentView(left)
            }
            
            // Center Title
            Spacer()
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
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
            HStack(spacing: DesignTokens.Spacing.xs) {
                // Flario logo - using Electric Lime for brand color
                Text(brandName)
                    .font(DesignTokens.Typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
            }
            
        case .appLogo(let size):
            AppLogo(size: size)

        case .appLogoWithTagline(let size, let tagline):
            VStack(spacing: 4) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2))

                Text(tagline)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
            }
            
        case .quotaBadge(_, let action):
            QuotaDisplayView(style: .compact, action: action)
            
        case .custom(let viewBuilder):
            viewBuilder()
            
        case .empty:
            EmptyView()
        }
    }
}

// MARK: - Header Content Types
enum HeaderContent {
    case brandLogo(String)
    case appLogo(CGFloat)
    case appLogoWithTagline(CGFloat, String) // size, tagline
    case quotaBadge(Int, () -> Void) // credits, action
    case custom(() -> AnyView) // Custom view builder for flexible content
    case empty
}

#Preview {
    VStack(spacing: 0) {
        // Home style
        UnifiedHeaderBar(
            title: "Flario",
            leftContent: .brandLogo("Flario"),
            rightContent: .quotaBadge(10, {})
        )
        
        // Chat style - Free user
        UnifiedHeaderBar(
            title: "Flario",
            leftContent: .brandLogo("Flario"),
            rightContent: .quotaBadge(5, {})
        )
        
        // Chat style with App Logo
        UnifiedHeaderBar(
            title: "",
            leftContent: .appLogo(32),
            rightContent: .quotaBadge(10, {})
        )
        
        // Library/Profile style
        UnifiedHeaderBar(
            title: "History",
            leftContent: nil,
            rightContent: nil
        )
    }
}

