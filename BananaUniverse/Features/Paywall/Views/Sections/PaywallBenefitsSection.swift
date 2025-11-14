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
            icon: "sparkles",
            title: "Unlimited AI Image Edits",
            description: "Process as many images as you want, no limits"
        ),
        PaywallBenefit(
            icon: "bolt.fill",
            title: "Faster Processing Priority",
            description: "Skip the queue and get results instantly"
        ),
        PaywallBenefit(
            icon: "star.fill",
            title: "Advanced AI Filters",
            description: "Access to advanced AI models and effects"
        )
    ]
}

