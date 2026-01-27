//
//  SearchResultRow.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2026-01-27.
//  Search result row component for FullScreenSearchView
//

import SwiftUI

struct SearchResultRow: View {
    let tool: Tool
    let onTap: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Thumbnail
                CachedAsyncImage(
                    url: tool.thumbnailURL,
                    placeholderIcon: tool.placeholderIcon
                )
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm))
                
                // Text content
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(tool.name)
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(DesignTokens.Text.primary(colorScheme))
                        .lineLimit(1)
                    
                    Text(tool.shortDescription ?? tool.description ?? "")
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignTokens.Text.tertiary(colorScheme))
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .frame(height: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(tool.name). \(tool.shortDescription ?? tool.description ?? ""). Double tap to select.")
    }
}

#Preview {
    VStack {
        SearchResultRow(
            tool: Theme(
                id: "remove_object",
                name: "Remove Object from Image",
                description: "Remove unwanted objects from your photos",
                shortDescription: "Remove unwanted objects",
                thumbnailURL: nil,
                category: "main_tools",
                modelName: "lama-cleaner",
                placeholderIcon: "eraser.fill",
                prompt: "Remove the selected object",
                isFeatured: false,
                isAvailable: true,
                requiresPro: false,
                defaultSettings: nil,
                createdAt: Date()
            ),
            onTap: {}
        )
        
        Divider()
        
        SearchResultRow(
            tool: Theme(
                id: "upscale",
                name: "Image Upscaler",
                description: "Enhance image resolution up to 4x",
                shortDescription: "Enhance resolution",
                thumbnailURL: nil,
                category: "restoration",
                modelName: "upscaler",
                placeholderIcon: "arrow.up.right.square",
                prompt: "Upscale image",
                isFeatured: true,
                isAvailable: true,
                requiresPro: false,
                defaultSettings: nil,
                createdAt: Date()
            ),
            onTap: {}
        )
    }
    .environmentObject(ThemeManager())
}
