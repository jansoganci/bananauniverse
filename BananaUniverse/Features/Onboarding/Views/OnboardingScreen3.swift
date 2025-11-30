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

            // Credit Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Brand.primary(colorScheme).opacity(0.3),
                                DesignTokens.Brand.secondary(colorScheme).opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: DesignTokens.Brand.primary(colorScheme).opacity(0.4), radius: 20, x: 0, y: 10)

                VStack(spacing: 4) {
                    Text("10")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(DesignTokens.Brand.primary(colorScheme))

                    Text("Credits")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                }
            }
            .scaleEffect(1.0)
            .animation(DesignTokens.Animation.spring, value: true)

            // Title
            Text("Start with 10 Free Credits")
                .font(DesignTokens.Typography.title1)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.md)

            // Description
            Text("Each transformation uses 1 credit. Buy more anytime.")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)

            // Example List
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                    Text("Collectible Figure — 1 credit")
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                }

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                    Text("Professional Headshot — 1 credit")
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                }

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                    Text("All tools included — No hidden fees")
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)

            Spacer()

            // Next Button (changed from Get Started)
            PrimaryButton(
                title: "Next",
                icon: "arrow.right",
                action: onComplete
            )
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.bottom, DesignTokens.Spacing.lg)
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
