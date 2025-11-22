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
        ZStack(alignment: .bottomLeading) {
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

            // Text overlay with gradient background
            VStack(alignment: .leading, spacing: 4) {
                // Category badge
                Text(getCategoryName(tool.category))
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.9))
                    .textCase(.uppercase)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)

                // Tool name
                Text(tool.name)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                // Short description
                if let shortDesc = tool.shortDescription {
                    Text(shortDesc)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                } else if let desc = tool.description {
                    // Fallback to truncated description if shortDescription doesn't exist
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                }

                // CTA button (Option 1: 14pt semibold rounded)
                HStack(spacing: 4) {
                    Text("Try Now")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                )
                .padding(.top, 4)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        .black.opacity(0.3),     // Darker at top
                        .black.opacity(0.85)     // Much darker at bottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
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
