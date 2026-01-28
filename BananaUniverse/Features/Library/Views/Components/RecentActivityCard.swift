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
                // Thumbnail
                CachedAsyncImage(
                    url: item.thumbnailURL,
                    placeholderIcon: iconForEffect(item.effectId)
                )
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
        .accessibilityHint("accessibility_double_tap_view".localized)
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

