//
//  CreditProductCard.swift
//  BananaUniverse
//
//  Credit product card component for paywall
//

import SwiftUI
import StoreKit

struct CreditProductCard: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            VStack(spacing: 0) {
                // Best Value Badge
                if isBestValue {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("BEST VALUE")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.premiumStart(colorScheme),
                                DesignTokens.Gradients.premiumEnd(colorScheme)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(DesignTokens.CornerRadius.xs, corners: [.topLeft, .topRight])
                }
                
                VStack(spacing: DesignTokens.Spacing.md) {
                    // Product info
                    HStack {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(product.displayName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                            
                            Text(product.description)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        // Price
                        Text(product.displayPrice)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(DesignTokens.Text.primary(colorScheme))
                    }
                    .padding(DesignTokens.Spacing.md)
                    
                    // Selection indicator
                    if isSelected {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(DesignTokens.Gradients.premiumStart(colorScheme))
                            Text("Selected")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DesignTokens.Gradients.premiumStart(colorScheme))
                        }
                        .padding(.bottom, DesignTokens.Spacing.md)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .fill(DesignTokens.Surface.secondary(colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                            .stroke(
                                isSelected
                                    ? DesignTokens.Gradients.premiumStart(colorScheme)
                                    : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .designShadow(DesignTokens.Shadow.sm)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

