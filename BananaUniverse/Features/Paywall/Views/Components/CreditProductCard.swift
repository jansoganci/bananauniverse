//
//  CreditProductCard.swift
//  BananaUniverse
//
//  Credit product card component for paywall
//

import SwiftUI
import RevenueCat

struct CreditProductCard: View {
    let package: Package
    let isSelected: Bool
    let isBestValue: Bool
    let isMostPopular: Bool
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            VStack(spacing: 0) {
                // Badge (Best Value or Most Popular)
                if isBestValue {
                    HStack {
                        Text("🔥")
                            .font(.system(size: 10))
                        Text("BEST VALUE")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(DesignTokens.Text.inverse)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(
                        LinearGradient(
                            colors: [
                                DesignTokens.Gradients.primaryStart(colorScheme),
                                DesignTokens.Gradients.primaryEnd(colorScheme)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(DesignTokens.CornerRadius.xs, corners: [.topLeft, .topRight])
                } else if isMostPopular {
                    HStack {
                        Text("💎")
                            .font(.system(size: 10))
                        Text("MOST POPULAR")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(DesignTokens.Text.inverse)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(
                        LinearGradient(
                            colors: [
                                DesignTokens.Brand.accent(colorScheme),
                                DesignTokens.Brand.accent(colorScheme).opacity(0.8)
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
                            Text(package.storeProduct.localizedTitle)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(DesignTokens.Text.primary(colorScheme))
                            
                            Text(package.storeProduct.localizedDescription)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        // Price
                        Text(package.storeProduct.localizedPriceString)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(DesignTokens.Text.primary(colorScheme))
                    }
                    .padding(DesignTokens.Spacing.md)
                    
                    // Selection indicator
                    if isSelected {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(DesignTokens.Brand.primary(colorScheme))
                            Text("Selected")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DesignTokens.Brand.primary(colorScheme))
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
                                    ? DesignTokens.Brand.primary(colorScheme)
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

