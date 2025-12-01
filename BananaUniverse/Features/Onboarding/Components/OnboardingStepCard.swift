//
//  OnboardingStepCard.swift
//  BananaUniverse
//
//  Created by Claude on 2025-11-22.
//  Purpose: Reusable step card for "How It Works" screen
//

import SwiftUI
import UIKit

struct OnboardingStepCard: View {
    let stepNumber: Int
    let iconName: String
    let title: String
    let description: String
    let iconColor: Color
    let screenshotImageName: String?

    @Environment(\.colorScheme) var colorScheme

    init(
        stepNumber: Int,
        iconName: String,
        title: String,
        description: String,
        iconColor: Color,
        screenshotImageName: String? = nil
    ) {
        self.stepNumber = stepNumber
        self.iconName = iconName
        self.title = title
        self.description = description
        self.iconColor = iconColor
        self.screenshotImageName = screenshotImageName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Screenshot (if provided and exists)
            if let screenshotImageName = screenshotImageName,
               UIImage(named: screenshotImageName) != nil {
                Image(screenshotImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            
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
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .fill(DesignTokens.Background.secondary(colorScheme))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
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
            iconColor: .orange,
            screenshotImageName: nil
        )

        OnboardingStepCard(
            stepNumber: 2,
            iconName: "camera.fill",
            title: "Upload your photo",
            description: "Take a picture or choose from your photo library",
            iconColor: .blue,
            screenshotImageName: nil
        )

        OnboardingStepCard(
            stepNumber: 3,
            iconName: "sparkles",
            title: "Generate & share",
            description: "Customize settings, hit generate, and share!",
            iconColor: .purple,
            screenshotImageName: nil
        )
    }
    .padding()
    .background(Color.black)
}
#endif
