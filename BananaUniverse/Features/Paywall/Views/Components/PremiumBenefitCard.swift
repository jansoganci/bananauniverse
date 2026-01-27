//
//  PremiumBenefitCard.swift
//  BananaUniverse
//
//  Benefit card component for paywall
//

import SwiftUI

struct BenefitCard: View {
    let icon: String
    let title: String
    let description: String
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.primaryStart(colorScheme).opacity(0.2),
                                DesignTokens.Gradients.primaryEnd(colorScheme).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.primaryStart(colorScheme),
                                DesignTokens.Gradients.primaryEnd(colorScheme)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Text content
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(DesignTokens.Surface.secondary(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    DesignTokens.Gradients.primaryStart(colorScheme).opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: DesignTokens.ShadowColors.default(colorScheme),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

