//
//  OnboardingScreen1.swift
//  BananaUniverse
//
//  Created by Claude on 2025-11-22.
//  Purpose: Welcome screen with hero image showcase
//

import SwiftUI

struct OnboardingScreen1: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Before/After Slider
            BeforeAfterSlider(
                beforeImageName: "OnboardingBefore",
                afterImageName: "OnboardingAfter"
            )
            .padding(.horizontal, DesignTokens.Spacing.md)

            // Title
            Text("Welcome to BananaUniverse")
                .font(DesignTokens.Typography.largeTitle)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.md)

            // Subtitle
            Text("Transform your photos into viral content in seconds")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
    }

}

// MARK: - Preview
#if DEBUG
#Preview {
    OnboardingScreen1()
        .background(Color.black)
}
#endif
