//
//  PaywallFooterSection.swift
//  BananaUniverse
//
//  Footer section for paywall
//

import SwiftUI

struct PaywallFooterSection: View {
    let isLoading: Bool
    let onRestore: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Restore purchases
            Button(action: onRestore) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                    }
                    Text("paywall_footer_restore".localized)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(DesignTokens.Brand.primary(colorScheme))
            }
            .disabled(isLoading)
            
            // Legal links
            HStack(spacing: 2) {
                Button("paywall_footer_terms".localized) {
                    if let url = URL(string: Config.termsOfServiceURL) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                
                Text("•")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                
                Button("paywall_footer_privacy".localized) {
                    if let url = URL(string: Config.privacyPolicyURL) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
            }
        }
    }
}

