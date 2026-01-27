//
//  PaywallCTAButton.swift
//  BananaUniverse
//
//  CTA button for paywall
//

import SwiftUI
import RevenueCat

struct PaywallCTAButton: View {
    let selectedPackage: Package?
    let isLoading: Bool
    let onPurchase: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    private var buttonText: String {
        if isLoading {
            return "Processing..."
        } else if selectedPackage != nil {
            return "Continue Creating →"
        } else {
            return "Select a Package"
        }
    }
    
    var body: some View {
        Button(action: onPurchase) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.9)
                        .tint(DesignTokens.Text.onBrand(colorScheme))
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Text(buttonText)
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(DesignTokens.Text.onBrand(colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if selectedPackage != nil && !isLoading {
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.primaryStart(colorScheme),
                                DesignTokens.Gradients.primaryEnd(colorScheme)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.primaryStart(colorScheme).opacity(0.5),
                                DesignTokens.Gradients.primaryEnd(colorScheme).opacity(0.5)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .shadow(
                color: selectedPackage != nil ? DesignTokens.ShadowColors.primary(colorScheme) : Color.clear,
                radius: selectedPackage != nil ? 16 : 0,
                x: 0,
                y: 8
            )
        }
        .disabled(selectedPackage == nil || isLoading)
        .opacity((selectedPackage != nil && !isLoading) ? 1.0 : 0.6)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedPackage != nil)
        .accessibilityLabel(buttonText)
        .accessibilityHint("Tap to purchase selected product")
    }
}

