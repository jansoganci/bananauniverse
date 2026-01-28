//
//  PaywallHeroSection.swift
//  BananaUniverse
//
//  Minimalist hero section - no icons, just typography
//

import SwiftUI

struct PaywallHeroSection: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Text("paywall_title".localized)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(DesignTokens.Text.primary(colorScheme))

            Text("paywall_subtitle".localized)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
        }
    }
}
