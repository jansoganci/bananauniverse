//
//  OnboardingProgressDots.swift
//  BananaUniverse
//
//  Created by Claude on 2025-11-22.
//  Purpose: Progress indicator dots for onboarding screens
//

import SwiftUI

struct OnboardingProgressDots: View {
    let currentIndex: Int
    let totalCount: Int

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(0..<totalCount, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? DesignTokens.Brand.secondary(colorScheme) : DesignTokens.Text.tertiary(colorScheme).opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                    .animation(DesignTokens.Animation.quick, value: currentIndex)
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    VStack(spacing: 20) {
        OnboardingProgressDots(currentIndex: 0, totalCount: 3)
        OnboardingProgressDots(currentIndex: 1, totalCount: 3)
        OnboardingProgressDots(currentIndex: 2, totalCount: 3)
    }
    .padding()
}
#endif
