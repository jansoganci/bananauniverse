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
            
            Text("library_error_title".localized)
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
                    Text("library_try_again".localized)
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .accessibilityLabel("library_try_again".localized)
            .accessibilityHint("library_accessibility_retry_hint".localized)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\("chat_error_title".localized): \(message). \("library_try_again".localized)")
    }
}
