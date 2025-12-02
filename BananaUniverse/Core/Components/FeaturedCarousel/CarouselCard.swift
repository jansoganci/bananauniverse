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
            AsyncImage(url: tool.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .empty:
                    placeholderView
                case .failure:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
            .frame(width: 350, height: 220)
            .clipped()

            // Floating category badge - top-right
            VStack {
                HStack {
                    Spacer()
                    Text(getCategoryName(tool.category))
                        .font(DesignTokens.Typography.caption2.bold())
                        .foregroundColor(.white.opacity(0.95))
                        .textCase(.uppercase)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                }
                Spacer()
            }

            // Bottom bar overlay
            VStack {
                Spacer()
                HStack(alignment: .center, spacing: 8) {
                    // Tool name
                    Text(tool.name)
                        .font(DesignTokens.Typography.headline.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    
                    Spacer()
                    
                    // CTA button
                    HStack(spacing: 4) {
                        Text("Try Now")
                            .font(.system(size: 15, weight: .semibold, design: .default))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.0),     // Start at 75% from top
                            .black.opacity(0.3),     // Mid at 87.5%
                            .black.opacity(0.7)      // End at bottom
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
            color: .black.opacity(0.2),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    // MARK: - Placeholder View

    private var placeholderView: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: tool.placeholderIcon)
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
        }
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
        .background(Color.black)
    }
}
#endif
