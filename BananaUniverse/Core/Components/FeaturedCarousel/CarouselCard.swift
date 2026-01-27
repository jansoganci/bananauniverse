//
//  CarouselCard.swift
//  BananaUniverse
//
//  Created by Claude on 2025-11-22.
//  Purpose: Featured carousel card with messaging overlay and CTA
//

import SwiftUI

struct CarouselCard: View {
    let tool: Theme
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Background image
            CachedAsyncImage(
                url: tool.thumbnailURL,
                placeholderIcon: tool.placeholderIcon
            )
            .frame(width: 350, height: 220)
            .clipped()

            // Floating category badge - top-right
            VStack {
                HStack {
                    Spacer()
                    Text(getCategoryName(tool.category))
                        .font(DesignTokens.Typography.caption2.bold())
                        .foregroundColor(DesignTokens.Text.inverse.opacity(0.95))
                        .textCase(.uppercase)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(
                            Capsule()
                                .fill(DesignTokens.Surface.overlay(colorScheme))
                        )
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: DesignTokens.Surface.overlay(colorScheme), radius: 4, x: 0, y: 2)
                        .padding(.top, DesignTokens.Spacing.sm)
                        .padding(.trailing, DesignTokens.Spacing.sm)
                }
                Spacer()
            }

            // Bottom bar overlay
            VStack {
                Spacer()
                HStack(alignment: .center, spacing: 8) {
                    // Tool name
                    if tool.name.isEmpty {
                        SkeletonView()
                            .frame(width: 120, height: 20)
                            .cornerRadius(4)
                    } else {
                        Text(tool.name)
                            .font(DesignTokens.Typography.headline.bold())
                            .foregroundColor(DesignTokens.Text.inverse)
                            .lineLimit(1)
                            .shadow(color: DesignTokens.Surface.overlay(colorScheme), radius: 2, x: 0, y: 1)
                    }
                    
                    Spacer()
                    
                    // CTA button with Electric Lime gradient
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text("Try Now")
                            .font(DesignTokens.Typography.callout)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(DesignTokens.Text.onBrand(colorScheme))
                    .padding(.horizontal, DesignTokens.Spacing.sm)
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
                    .cornerRadius(DesignTokens.CornerRadius.sm)
                    .shadow(color: DesignTokens.ShadowColors.primary(colorScheme), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.top, DesignTokens.Spacing.sm)
                .padding(.bottom, DesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .fill(DesignTokens.Surface.overlay(colorScheme))
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            DesignTokens.Surface.overlay(colorScheme).opacity(0.0),
                            DesignTokens.Surface.overlay(colorScheme).opacity(0.5),
                            DesignTokens.Surface.overlay(colorScheme).opacity(1.0)
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0.75),
                        endPoint: UnitPoint(x: 0.5, y: 1.0)
                    )
                )
            }
        }
        .frame(width: 350, height: 220)
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .shadow(
            color: DesignTokens.ShadowColors.default(colorScheme),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    // MARK: - Helper Functions

    /// Convert category ID to display name with emoji
    private func getCategoryName(_ categoryId: String) -> String {
        switch categoryId {
        case "trending":
            return "🔥 Trending"
        case "transformations":
            return "🎭 Transformation"
        case "pro_tools":
            return "📸 Pro Tools"
        case "enhancements":
            return "✨ Enhancement"
        case "artistic":
            return "🎨 Artistic"
        case "seasonal":
            return "🎉 Seasonal"
        default:
            return categoryId.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CarouselCard_Previews: PreviewProvider {
    static var previews: some View {
        CarouselCard(
            tool: Theme(
                id: "test",
                name: "Desktop Figurine",
                description: "Transform yourself into an adorable collectible desk toy with bobblehead style",
                shortDescription: "Turn yourself into a collectible desk toy",
                thumbnailURL: nil,
                category: "trending",
                modelName: "nano-banana/edit",
                placeholderIcon: "figure.stand",
                prompt: "...",
                isFeatured: true,
                isAvailable: true,
                requiresPro: false,
                defaultSettings: [:]
            )
        )
        .previewLayout(.sizeThatFits)
        .padding()
        .background(DesignTokens.Background.primary(.dark))
    }
}
#endif
