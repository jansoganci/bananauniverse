//
//  ErrorView.swift
//  noname_banana
//
//  Created by AI Assistant on 16.10.2025.
//  Error state view for Library screen
//

import SwiftUI

// MARK: - Error State View
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(DesignTokens.Semantic.error(themeManager.resolvedColorScheme))
                .accessibilityHidden(true)
            
            Text("Something went wrong")
                .font(DesignTokens.Typography.title3)
                .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                .accessibilityAddTraits(.isHeader)
            
            Text(message)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)
            
            Button(action: {
                DesignTokens.Haptics.impact(.medium)
                onRetry()
            }) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                    Text("Try Again")
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .accessibilityLabel("Try again")
            .accessibilityHint("Double tap to retry loading history")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message). Try again button available.")
    }
}
