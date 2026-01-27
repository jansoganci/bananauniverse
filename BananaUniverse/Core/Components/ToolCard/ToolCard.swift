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
                // Thumbnail Image
                CachedAsyncImage(
                    url: tool.thumbnailURL,
                    placeholderIcon: tool.placeholderIcon
                )
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm))
                .frame(height: 120)
                
                // Title
                if tool.name.isEmpty {
                    SkeletonView()
                        .frame(width: 80, height: 16)
                        .cornerRadius(4)
                } else {
                    Text(tool.name)
                        .font(DesignTokens.Typography.headline)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
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

