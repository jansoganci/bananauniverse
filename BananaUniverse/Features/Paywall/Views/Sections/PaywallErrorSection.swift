//
//  PaywallErrorSection.swift
//  BananaUniverse
//
//  Error state section for paywall
//

import SwiftUI

struct PaywallErrorSection: View {
    let errorMessage: String?
    let onRetry: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Semantic.warning(colorScheme))
            
            Text("paywall_error_title".localized)
                .font(DesignTokens.Typography.headline)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
            
            Text(errorMessage ?? "paywall_error_connection_message".localized)
                .font(DesignTokens.Typography.subheadline)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                .multilineTextAlignment(.center)
            
            Button(action: onRetry) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "arrow.clockwise")
                    Text("paywall_error_retry".localized)
                }
                .font(DesignTokens.Typography.headline)
                .foregroundColor(DesignTokens.Text.onBrand(colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.Layout.buttonHeight)
                .background(
                    LinearGradient(
                        colors: [
                            DesignTokens.Gradients.primaryStart(colorScheme),
                            DesignTokens.Gradients.primaryEnd(colorScheme)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(DesignTokens.CornerRadius.md)
            }
            .padding(.top, DesignTokens.Spacing.sm)
        }
        .padding(DesignTokens.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .fill(DesignTokens.Surface.secondary(colorScheme))
        )
    }
}

