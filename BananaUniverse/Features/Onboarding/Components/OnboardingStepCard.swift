//
//  OnboardingStepCard.swift
//  BananaUniverse
//
//  Created by Claude on 2025-11-22.
//  Purpose: Reusable step card for "How It Works" screen
//

import SwiftUI

struct OnboardingStepCard: View {
    let stepNumber: Int
    let iconName: String
    let title: String
    let description: String
    let iconColor: Color

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            // Step number badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                iconColor.opacity(0.2),
                                iconColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Text("\(stepNumber)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(DesignTokens.Text.primary(colorScheme))

                // Description
                Text(description)
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Icon
            Image(systemName: iconName)
                .font(.system(size: 28))
                .foregroundColor(iconColor)
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(DesignTokens.Background.secondary(colorScheme))
        )
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    VStack(spacing: 16) {
        OnboardingStepCard(
            stepNumber: 1,
            iconName: "paintpalette.fill",
            title: "Choose your style",
            description: "Browse 19+ AI themes: toys, art, pro photos",
            iconColor: .orange
        )

        OnboardingStepCard(
            stepNumber: 2,
            iconName: "camera.fill",
            title: "Upload your photo",
            description: "Take a picture or choose from your photo library",
            iconColor: .blue
        )

        OnboardingStepCard(
            stepNumber: 3,
            iconName: "sparkles",
            title: "Generate & share",
            description: "Customize settings, hit generate, and share!",
            iconColor: .purple
        )
    }
    .padding()
    .background(Color.black)
}
#endif
