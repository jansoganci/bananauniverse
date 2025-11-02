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
            VStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                // Image placeholder (SF Symbol)
                Image(systemName: tool.placeholderIcon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                    .frame(height: 80)
                
                // Title
                Text(tool.title)
                    .font(DesignTokens.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 160)
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
            tool: Tool(
                id: "remove_object",
                title: "Remove Object from Image",
                imageURL: nil as URL?,
                category: "main_tools",
                requiresPro: false,
                modelName: "lama-cleaner",
                placeholderIcon: "eraser.fill",
                prompt: "Remove the selected object"
            ),
            onTap: {}
        )
        
        ToolCard(
            tool: Tool(
                id: "linkedin_headshot",
                title: "LinkedIn Headshot",
                imageURL: nil as URL?,
                category: "pro_looks",
                requiresPro: false,
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

