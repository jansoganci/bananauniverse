//
//  PaywallLoadingSection.swift
//  BananaUniverse
//
//  Loading state section for paywall
//

import SwiftUI

struct PaywallLoadingSection: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(DesignTokens.Brand.primary(colorScheme))
            
            Text("paywall_loading".localized)
                .font(DesignTokens.Typography.subheadline)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xl)
    }
}

