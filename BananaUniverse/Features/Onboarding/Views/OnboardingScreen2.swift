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

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Title
            Text("How It Works")
                .font(DesignTokens.Typography.title1)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                .padding(.top, DesignTokens.Spacing.xl)

            VStack(spacing: DesignTokens.Spacing.md) {
                // Step 1: Choose your style
                OnboardingStepCard(
                    stepNumber: 1,
                    iconName: "paintpalette.fill",
                    title: "Choose your style",
                    description: "Browse 19+ AI themes: toys, art, pro photos",
                    iconColor: DesignTokens.Brand.primary(colorScheme)
                )

                // Step 2: Upload your photo
                OnboardingStepCard(
                    stepNumber: 2,
                    iconName: "camera.fill",
                    title: "Upload your photo",
                    description: "Take a picture or choose from your photo library",
                    iconColor: .blue
                )

                // Step 3: Generate & share
                OnboardingStepCard(
                    stepNumber: 3,
                    iconName: "sparkles",
                    title: "Generate & share",
                    description: "Customize settings, hit generate, and share!",
                    iconColor: DesignTokens.Brand.secondary(colorScheme)
                )
            }
            .padding(.horizontal, DesignTokens.Spacing.md)

            Spacer()
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
