//
//  StatusBadge.swift
//  noname_banana
//
//  Created by AI Assistant on 16.10.2025.
//  Status badge component for Library screen
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
            // Adaptive text color for "Completed" badge readability
            // DesignTokens.Text.onSuccess not available, using fallback
            if themeManager.resolvedColorScheme == .dark {
                // Bright cyan background in dark mode → use black text for contrast
                return Color.black
            } else {
                // Dark teal background in light mode → use black text
                return Color.black
            }
        } else {
            // Other statuses maintain white text for consistency
            return .white
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
            .accessibilityLabel("Status: \(status.displayText)")
            .accessibilityAddTraits(.isStaticText)
    }
}
