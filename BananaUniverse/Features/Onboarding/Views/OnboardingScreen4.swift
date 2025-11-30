//
//  OnboardingScreen4.swift
//  BananaUniverse
//
//  Created by AI Assistant
//  Purpose: Data deletion policy information screen
//

import SwiftUI

struct OnboardingScreen4: View {
    let onComplete: () -> Void
    
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Brand.primary(colorScheme).opacity(0.2),
                                DesignTokens.Brand.secondary(colorScheme).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 50))
                    .foregroundColor(DesignTokens.Brand.primary(colorScheme))
            }
            .padding(.bottom, DesignTokens.Spacing.md)

            // Title
            Text("Important: Save Your Images")
                .font(DesignTokens.Typography.title1)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.md)

            // Description
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Warning 1: Result page close
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Save before closing")
                            .font(DesignTokens.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignTokens.Text.primary(colorScheme))
                        
                        Text("Your processed images will be deleted from our servers when you close the result page. Make sure to save them to your device before closing.")
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                    }
                }
                
                // Warning 2: Auto deletion
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automatic deletion")
                            .font(DesignTokens.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignTokens.Text.primary(colorScheme))
                        
                        Text("Images are automatically deleted from our servers after 1 hour. Please save important images to your device.")
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)

            Spacer()

            // Get Started Button
            PrimaryButton(
                title: "I Understand",
                icon: "checkmark.circle.fill",
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
    OnboardingScreen4(onComplete: {
        print("I Understand tapped")
    })
    .background(Color.black)
}
#endif

