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
                    Text("Restore Purchases")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(DesignTokens.Text.link(colorScheme))
            }
            .disabled(isLoading)
            
            // Legal links
            HStack(spacing: DesignTokens.Spacing.lg) {
                Button("Terms") {
                    if let url = URL(string: Config.termsOfServiceURL) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(DesignTokens.Text.link(colorScheme))
                
                Text("•")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
                
                Button("Privacy") {
                    if let url = URL(string: Config.privacyPolicyURL) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(DesignTokens.Text.link(colorScheme))
            }
        }
    }
}

