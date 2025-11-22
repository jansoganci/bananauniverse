//
//  PaywallHeroSection.swift
//  BananaUniverse
//
//  Hero section for paywall
//

import SwiftUI

struct PaywallHeroSection: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Icon/Emoji
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.premiumStart(colorScheme).opacity(0.3),
                                DesignTokens.Gradients.premiumEnd(colorScheme).opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.premiumStart(colorScheme),
                                DesignTokens.Gradients.premiumEnd(colorScheme)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.bottom, DesignTokens.Spacing.sm)
            
            // Title
            Text("Get More Credits")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                .multilineTextAlignment(.center)
                .lineLimit(3)

            // Subtitle
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("Keep creating amazing photos")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignTokens.Gradients.premiumStart(colorScheme))
                
                Text("Instant access • No subscription")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
}

