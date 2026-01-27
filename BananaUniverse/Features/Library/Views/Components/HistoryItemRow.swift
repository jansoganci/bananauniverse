//
//  HistoryItemRow.swift
//  noname_banana
//
//  Created by AI Assistant on 16.10.2025.
//  History item row component for Library screen
//

import SwiftUI

// MARK: - History Item Row
struct HistoryItemRow: View {
    let item: HistoryItem
    let onTap: () -> Void
    let onSelect: () -> Void
    let onRerun: () -> Void
    let onShare: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            DesignTokens.Haptics.impact(.light)
            onSelect()
        }) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Thumbnail
                CachedAsyncImage(url: item.thumbnailURL)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm))
                    .accessibilityHidden(true)
                    .id(item.thumbnailURL?.absoluteString ?? item.id)
                
                // Info Section
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(item.effectTitle)
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(DesignTokens.Text.accent(themeManager.resolvedColorScheme))
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    
                    // Status Badge
                    StatusBadge(status: item.status)
                    
                    Text(item.relativeDate)
                        .font(DesignTokens.Typography.footnote)
                        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                }
                
                Spacer()
                
                // Action Menu
                Menu {
                    Button {
                        DesignTokens.Haptics.impact(.medium)
                        onRerun()
                    } label: {
                        Label("Re-run", systemImage: "arrow.clockwise")
                    }
                    
                    Button {
                        DesignTokens.Haptics.impact(.light)
                        onShare()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        DesignTokens.Haptics.impact(.light)
                        onDownload()
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                    
                    Button(role: .destructive) {
                        DesignTokens.Haptics.warning()
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                        .frame(width: DesignTokens.Layout.buttonHeight, height: DesignTokens.Layout.buttonHeight)
                        .accessibilityLabel("More actions")
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.effectTitle), \(item.status.displayText), \(item.relativeDate)")
        .accessibilityHint("Double tap to view details")
    }
}
