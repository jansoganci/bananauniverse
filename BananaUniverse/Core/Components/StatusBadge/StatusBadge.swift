//
//  StatusBadge.swift
//  BananaUniverse
//
//  Created by AI Assistant on 16.10.2025.
//  Status badge component - moved to Core for reusability
//

import SwiftUI

// MARK: - Status Badge Component
struct StatusBadge: View {
    let status: JobStatus
    @EnvironmentObject var themeManager: ThemeManager
    
    private var badgeBackgroundColor: Color {
        status.badgeColor(for: themeManager.resolvedColorScheme)
    }
    
    private var badgeTextColor: Color {
        if status == .completed {
            // Use DesignTokens.Text.onBrand for better contrast
            return DesignTokens.Text.onBrand(themeManager.resolvedColorScheme)
        } else {
            // Other statuses maintain white text for consistency
            return DesignTokens.Text.inverse
        }
    }
    
    var body: some View {
        Text(status.displayText)
            .font(DesignTokens.Typography.caption2)
            .foregroundColor(badgeTextColor)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(badgeBackgroundColor)
            .cornerRadius(DesignTokens.CornerRadius.round)
            .accessibilityLabel(String(format: "accessibility_status".localized, status.displayText))
            .accessibilityAddTraits(.isStaticText)
    }
}
