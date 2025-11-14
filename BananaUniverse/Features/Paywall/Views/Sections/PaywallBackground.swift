//
//  PaywallBackground.swift
//  BananaUniverse
//
//  Animated background for paywall
//

import SwiftUI

struct PaywallBackground: View {
    let animateGradient: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    DesignTokens.Background.primary(colorScheme),
                    DesignTokens.Background.secondary(colorScheme),
                    DesignTokens.Background.primary(colorScheme)
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            
            // Accent gradient overlay
            LinearGradient(
                colors: [
                    DesignTokens.Gradients.premiumStart(colorScheme).opacity(0.1),
                    DesignTokens.Gradients.premiumEnd(colorScheme).opacity(0.05),
                    DesignTokens.Gradients.premiumStart(colorScheme).opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

