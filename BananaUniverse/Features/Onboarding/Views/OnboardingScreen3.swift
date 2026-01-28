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
    @State private var animateItems = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Credit Badge (smaller, less prominent)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Brand.primary(colorScheme).opacity(0.2),
                                DesignTokens.Brand.primary(colorScheme).opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: DesignTokens.Brand.primary(colorScheme).opacity(0.2), radius: 8, x: 0, y: 4)

                VStack(spacing: 2) {
                    Text("10")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(DesignTokens.Brand.primary(colorScheme))

                    Text("onboarding_screen3_credits_label".localized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                }
            }
            .scaleEffect(animateItems ? 1 : 0.5)
            .opacity(animateItems ? 1 : 0)
            .animation(DesignTokens.Animation.bouncy.delay(0.1), value: animateItems)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("onboarding_screen3_bonus_accessibility".localized)

            // Title
            Text("onboarding_screen3_title".localized)
                .font(DesignTokens.Typography.title1)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 10)
                .animation(DesignTokens.Animation.smooth.delay(0.2), value: animateItems)

            // Description
            Text("onboarding_screen3_subtitle".localized)
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 10)
                .animation(DesignTokens.Animation.smooth.delay(0.3), value: animateItems)

            // Example List
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                    Text("onboarding_screen3_feature1".localized)
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                }

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                    Text("onboarding_screen3_feature2".localized)
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                }

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                    Text("onboarding_screen3_feature3".localized)
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .opacity(animateItems ? 1 : 0)
            .offset(y: animateItems ? 0 : 10)
            .animation(DesignTokens.Animation.smooth.delay(0.4), value: animateItems)

            Spacer()
        }
        .onAppear {
            withAnimation(DesignTokens.Animation.smooth) {
                animateItems = true
            }
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
