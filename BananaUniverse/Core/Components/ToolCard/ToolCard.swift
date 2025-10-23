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
    let showPremiumBadge: Bool // Control badge visibility
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        AppCard(onTap: onTap) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Title - Prominent, hero element
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    Text(tool.title)
                        .font(DesignTokens.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // PRO Lock Badge - Top right corner
                    if tool.requiresPro && showPremiumBadge {
                        ZStack {
                            Circle()
                                .fill(DesignTokens.Brand.accent(themeManager.resolvedColorScheme))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // Description - Supporting text
                Text(getToolDescription())
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Icon - Small accent at bottom
                HStack {
                    Image(systemName: tool.placeholderIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                    
                    Spacer()
                    
                    // Action indicator
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignTokens.Text.tertiary(themeManager.resolvedColorScheme))
                }
            }
            .frame(height: 160)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get brief description based on tool category
    private func getToolDescription() -> String {
        switch tool.id {
        case "remove_object":
            return "Erase unwanted objects seamlessly"
        case "remove_background":
            return "Clean background removal in seconds"
        case "put_items_on_models":
            return "Virtual try-on for clothing & accessories"
        case "add_objects":
            return "Add realistic objects to any scene"
        case "change_perspective":
            return "Transform image angles & viewpoints"
        case "generate_series":
            return "Create consistent image variations"
        case "style_transfer":
            return "Apply artistic styles to your photos"
        case "linkedin_headshot":
            return "Professional headshots for LinkedIn"
        case "passport_photo":
            return "Passport-ready photos instantly"
        case "twitter_avatar":
            return "Eye-catching social media avatars"
        case "gradient_headshot":
            return "Modern headshots with gradients"
        case "resume_photo":
            return "Professional resume portraits"
        case "slide_background":
            return "Clean backgrounds for presentations"
        case "thumbnail_generator":
            return "Engaging thumbnails for content"
        case "cv_portrait":
            return "Portfolio-ready professional photos"
        case "profile_banner":
            return "Stylish banners for social profiles"
        case "designer_id_photo":
            return "Contemporary designer-style ID photos"
        case "image_upscaler":
            return "Enhance resolution up to 4x quality"
        case "historical_photo_restore":
            return "Restore old & damaged photographs"
        default:
            return "Transform your images with AI"
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
            onTap: {},
            showPremiumBadge: true
        )
        
        ToolCard(
            tool: Tool(
                id: "linkedin_headshot",
                title: "LinkedIn Headshot",
                imageURL: nil as URL?,
                category: "pro_looks",
                requiresPro: true,
                modelName: "professional-headshot",
                placeholderIcon: "person.crop.square",
                prompt: "Create a professional LinkedIn headshot"
            ),
            onTap: {},
            showPremiumBadge: false
        )
    }
    .padding()
    .background(DesignTokens.Background.primary(.light))
    .environmentObject(ThemeManager())
}

