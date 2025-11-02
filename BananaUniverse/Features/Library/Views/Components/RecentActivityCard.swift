//
//  RecentActivityCard.swift
//  BananaUniverse
//
//  Horizontal preview card for recent activity section
//  Phase 3: Recent Activity Section
//

import SwiftUI

struct RecentActivityCard: View {
    let item: HistoryItem
    let onTap: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    private var colorScheme: ColorScheme {
        themeManager.resolvedColorScheme
    }
    
    var body: some View {
        Button(action: {
            DesignTokens.Haptics.impact(.light)
            onTap()
        }) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                // Thumbnail (real image or fallback)
                Group {
                    if let thumbnailURL = item.thumbnailURL {
                        AsyncImage(url: thumbnailURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure(_), .empty:
                                // Fallback to gradient with icon
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                DesignTokens.Brand.primary(colorScheme).opacity(0.6),
                                                DesignTokens.Brand.secondary(colorScheme).opacity(0.4)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Image(systemName: iconForEffect(item.effectId))
                                            .font(.system(size: 32, weight: .medium))
                                            .foregroundColor(.white.opacity(0.9))
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        // No thumbnail: show gradient placeholder
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DesignTokens.Brand.primary(colorScheme).opacity(0.6),
                                        DesignTokens.Brand.secondary(colorScheme).opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: iconForEffect(item.effectId))
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            )
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
                .designShadow(DesignTokens.Shadow.md)
                
                // Title
                Text(item.effectTitle)
                    .font(.system(size: 17, weight: .medium, design: .default))
                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                    .lineLimit(2)
                    .frame(width: 120, alignment: .leading)
                
                // Time ago
                Text(item.relativeDate)
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                    .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 120, height: 180)
        .accessibilityLabel("\(item.effectTitle), \(item.relativeDate)")
        .accessibilityHint("Double tap to view")
    }
    
    // MARK: - Helper Functions
    
    /// Maps effect ID to appropriate SF Symbol icon
    private func iconForEffect(_ effectId: String) -> String {
        switch effectId {
        case "nano-banana-edit":
            return "wand.and.stars"
        case "upscale":
            return "arrow.up.circle.fill"
        default:
            return "photo.fill"
        }
    }
}

