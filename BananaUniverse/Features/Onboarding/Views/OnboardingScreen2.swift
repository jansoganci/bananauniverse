//
//  OnboardingScreen2.swift
//  BananaUniverse
//
//  Created by Claude on 2025-11-22.
//  Purpose: How It Works - 3-step process explanation
//

import SwiftUI

struct OnboardingScreen2: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var animateItems = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Title
            Text("onboarding_screen2_title".localized)
                .font(DesignTokens.Typography.title1)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                .padding(.top, DesignTokens.Spacing.xl)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 10)

            VStack(spacing: DesignTokens.Spacing.md) {
                // Step 1: Choose your style
                OnboardingStepCard(
                    stepNumber: 1,
                    iconName: "paintpalette.fill",
                    title: "onboarding_screen2_step1_title".localized,
                    description: "onboarding_screen2_step1_description".localized,
                    iconColor: DesignTokens.Brand.primary(colorScheme),
                    screenshotImageName: "onboarding_screenshot_step1" // Add to Assets.xcassets
                )
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(DesignTokens.Animation.spring.delay(0.1), value: animateItems)

                // Step 2: Upload your photo
                OnboardingStepCard(
                    stepNumber: 2,
                    iconName: "camera.fill",
                    title: "onboarding_screen2_step2_title".localized,
                    description: "onboarding_screen2_step2_description".localized,
                    iconColor: DesignTokens.Brand.primary(colorScheme),
                    screenshotImageName: "onboarding_screenshot_step2" // Add to Assets.xcassets
                )
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(DesignTokens.Animation.spring.delay(0.2), value: animateItems)

                // Step 3: Generate & share
                OnboardingStepCard(
                    stepNumber: 3,
                    iconName: "sparkles",
                    title: "onboarding_screen2_step3_title".localized,
                    description: "onboarding_screen2_step3_description".localized,
                    iconColor: DesignTokens.Brand.primary(colorScheme),
                    screenshotImageName: "onboarding_screenshot_step3" // Add to Assets.xcassets
                )
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(DesignTokens.Animation.spring.delay(0.3), value: animateItems)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)

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
    OnboardingScreen2()
        .background(Color.black)
}
#endif
