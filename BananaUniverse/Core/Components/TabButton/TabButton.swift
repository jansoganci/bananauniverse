//
//  TabButton.swift
//  noname_banana
//
//  Created by AI Assistant on 16.10.2025.
//  Reusable Tab Button Component
//

import SwiftUI

// MARK: - Reusable Tab Button Component
struct TabButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let onTap: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                
                Text(label)
                    .font(DesignTokens.Typography.callout)
                    .fontWeight(.medium)
            }
            .foregroundColor(isActive ? .white : DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(isActive ? DesignTokens.Brand.secondary(themeManager.resolvedColorScheme) : DesignTokens.Surface.secondary(themeManager.resolvedColorScheme))
            .cornerRadius(DesignTokens.CornerRadius.round)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HStack(spacing: DesignTokens.Spacing.sm) {
        TabButton(icon: "wrench.and.screwdriver", label: "Main Tools", isActive: true, onTap: {})
        TabButton(icon: "camera.fill", label: "Pro Looks", isActive: false, onTap: {})
        TabButton(icon: "arrow.triangle.2.circlepath", label: "Restoration", isActive: false, onTap: {})
    }
    .padding()
    .background(DesignTokens.Background.primary(.light))
    .environmentObject(ThemeManager())
}

