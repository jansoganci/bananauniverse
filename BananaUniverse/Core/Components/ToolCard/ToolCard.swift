//
//  ToolCard.swift
//  BananaUniverse
//
//  Created by AI Assistant on 16.10.2025.
//  Reusable Tool Card Component
//

import SwiftUI

// MARK: - Tool Card Component
struct ToolCard: View {
    let tool: Tool
    let onTap: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        AppCard(onTap: onTap) {
            VStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                // Thumbnail Image - use AsyncImage if thumbnailURL exists, otherwise SF Symbol
                if let thumbnailURL = tool.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm))
                        case .failure:
                            // Fallback to SF Symbol if image fails to load
                            Image(systemName: tool.placeholderIcon)
                                .font(.system(size: 56, weight: .medium))
                                .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                                .frame(height: 120)
                        case .empty:
                            // Loading state - show placeholder
                            ProgressView()
                                .frame(width: 120, height: 120)
                        @unknown default:
                            Image(systemName: tool.placeholderIcon)
                                .font(.system(size: 56, weight: .medium))
                                .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                                .frame(height: 120)
                        }
                    }
                    .frame(height: 120)
                } else {
                    // No thumbnail URL - use SF Symbol
                    Image(systemName: tool.placeholderIcon)
                        .font(.system(size: 56, weight: .medium))
                        .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                        .frame(height: 120)
                }
                
                // Title
                Text(tool.name)
                    .font(DesignTokens.Typography.headline)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 180)
        }
    }
    
}

#Preview {
    LazyVGrid(
        columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ],
        spacing: 8
    ) {
        ToolCard(
            tool: Theme(
                id: "remove_object",
                name: "Remove Object from Image",
                category: "main_tools",
                modelName: "lama-cleaner",
                placeholderIcon: "eraser.fill",
                prompt: "Remove the selected object"
            ),
            onTap: {}
        )
        
        ToolCard(
            tool: Theme(
                id: "linkedin_headshot",
                name: "LinkedIn Headshot",
                category: "pro_looks",
                modelName: "professional-headshot",
                placeholderIcon: "person.crop.square",
                prompt: "Create a professional LinkedIn headshot"
            ),
            onTap: {}
        )
    }
    .padding()
    .background(DesignTokens.Background.primary(.light))
    .environmentObject(ThemeManager())
}

