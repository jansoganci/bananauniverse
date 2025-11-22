//
//  PaywallBenefitsSection.swift
//  BananaUniverse
//
//  Benefits section for paywall
//

import SwiftUI

struct PaywallBenefitsSection: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ForEach(PaywallBenefits.all, id: \.title) { benefit in
                BenefitCard(
                    icon: benefit.icon,
                    title: benefit.title,
                    description: benefit.description
                )
            }
        }
    }
}

struct PaywallBenefit {
    let icon: String
    let title: String
    let description: String
}

enum PaywallBenefits {
    static let all: [PaywallBenefit] = [
        PaywallBenefit(
            icon: "wand.and.stars",
            title: "🎭 Boring → Viral",
            description: "One tap away"
        ),
        PaywallBenefit(
            icon: "camera.fill",
            title: "📸 Your best look",
            description: "Every single time"
        ),
        PaywallBenefit(
            icon: "bolt.fill",
            title: "⚡ Instant magic",
            description: "Zero effort"
        )
    ]
}

