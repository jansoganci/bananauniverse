//
//  OnboardingScreen3.swift
//  BananaUniverse
//
//  Created by Claude on 2025-11-22.
//  Purpose: Credits explanation with Get Started CTA
//

import SwiftUI

struct OnboardingScreen3: View {
    let onComplete: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Credit Badge (smaller, less prominent)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Brand.secondary(colorScheme).opacity(0.2),
                                DesignTokens.Brand.secondary(colorScheme).opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: DesignTokens.Brand.secondary(colorScheme).opacity(0.2), radius: 8, x: 0, y: 4)

                VStack(spacing: 2) {
                    Text("10")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(DesignTokens.Brand.secondary(colorScheme))

                    Text("Credits")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                }
            }

            // Title
            Text("Start with 10 Free Credits")
                .font(DesignTokens.Typography.title1)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.md)

            // Description
            Text("Standard tools: 1 credit. Pro tools: 4-8 credits. Buy more anytime.")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)

            // Example List
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Brand.secondary(colorScheme))
                    Text("Collectible Figure — 1 credit")
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                }

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Brand.secondary(colorScheme))
                    Text("Professional Headshot — 4 credits")
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                }

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Brand.secondary(colorScheme))
                    Text("All tools included — No hidden fees")
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)

            Spacer()
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    OnboardingScreen3(onComplete: {
        print("Get Started tapped")
    })
    .background(Color.black)
}
#endif
