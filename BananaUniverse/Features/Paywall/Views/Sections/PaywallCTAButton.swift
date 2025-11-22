//
//  PaywallCTAButton.swift
//  BananaUniverse
//
//  CTA button for paywall
//

import SwiftUI
import StoreKit

struct PaywallCTAButton: View {
    let selectedProduct: Product?
    let isLoading: Bool
    let onPurchase: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    private var buttonText: String {
        if isLoading {
            return "Processing..."
        } else if selectedProduct != nil {
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
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Text(buttonText)
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if selectedProduct != nil && !isLoading {
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.premiumStart(colorScheme),
                                DesignTokens.Gradients.premiumEnd(colorScheme)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.premiumStart(colorScheme).opacity(0.5),
                                DesignTokens.Gradients.premiumEnd(colorScheme).opacity(0.5)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .shadow(
                color: selectedProduct != nil ? DesignTokens.Gradients.premiumStart(colorScheme).opacity(0.4) : Color.clear,
                radius: selectedProduct != nil ? 16 : 0,
                x: 0,
                y: 8
            )
        }
        .disabled(selectedProduct == nil || isLoading)
        .opacity((selectedProduct != nil && !isLoading) ? 1.0 : 0.6)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedProduct != nil)
        .accessibilityLabel(buttonText)
        .accessibilityHint("Tap to purchase selected product")
    }
}

