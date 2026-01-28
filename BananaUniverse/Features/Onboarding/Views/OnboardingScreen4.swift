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
                                DesignTokens.Brand.secondary(colorScheme).opacity(0.2),
                                DesignTokens.Brand.secondary(colorScheme).opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 50))
                    .foregroundColor(DesignTokens.Brand.secondary(colorScheme))
            }
            .padding(.bottom, DesignTokens.Spacing.md)

            // Title
            Text("onboarding_screen4_title".localized)
                .font(DesignTokens.Typography.title1)
                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.md)

            // Description
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Warning 1: Result page close
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(DesignTokens.Semantic.warning(colorScheme))
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("onboarding_screen4_step1_title".localized)
                            .font(DesignTokens.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignTokens.Text.primary(colorScheme))
                        
                        Text("onboarding_screen4_step1_description".localized)
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                    }
                }
                
                // Warning 2: Auto deletion
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(DesignTokens.Brand.accent(colorScheme))
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("onboarding_screen4_step2_title".localized)
                            .font(DesignTokens.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignTokens.Text.primary(colorScheme))
                        
                        Text("onboarding_screen4_step2_description".localized)
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)

            Spacer()

            // Get Started Button
            PrimaryButton(
                title: "onboarding_screen4_button".localized,
                icon: "checkmark.circle.fill",
                accentColor: DesignTokens.Brand.secondary,
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

