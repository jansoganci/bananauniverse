//
//  FeaturedToolCard.swift
//  BananaUniverse
//
//  Created by AI Assistant on 22.10.2025.
//  Hero card component for featured tools
//

import SwiftUI

// MARK: - Featured Tool Card Component
struct FeaturedToolCard: View {
    // MARK: - Properties
    let tool: Tool
    let onUseTool: () -> Void
    let onLearnMore: () -> Void
    
    // MARK: - State
    @State private var isPressed = false
    @StateObject private var creditManager = HybridCreditManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        AppCard(onTap: {
            // Add haptic feedback for featured card tap
            DesignTokens.Haptics.impact(.medium)
            onUseTool()
        }) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Featured Badge - Top left
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignTokens.Text.onGold)
                    
                    Text("FEATURED")
                        .font(DesignTokens.Typography.caption1)
                        .fontWeight(.bold)
                        .foregroundColor(DesignTokens.Text.onGold)
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignTokens.Brand.primary(themeManager.resolvedColorScheme),
                                    DesignTokens.Brand.accent(themeManager.resolvedColorScheme)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                
                // Tool Title - Prominent
                Text(tool.title)
                    .font(DesignTokens.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Description - Supporting text
                Text(getToolDescription())
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Bottom row: Icon + Use Tool Button
                HStack(spacing: DesignTokens.Spacing.md) {
                    // Small icon at bottom left
                    Image(systemName: tool.placeholderIcon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                    
                    Spacer()
                    
                    // Use Tool Button
                    Button(action: {
                        DesignTokens.Haptics.impact(.medium)
                        onUseTool()
                    }) {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            // Warning icon when quota is low
                            if creditManager.shouldShowQuotaWarning {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .semibold))
                            
                            Text("Use Tool")
                                .font(DesignTokens.Typography.callout)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(DesignTokens.Text.onGold)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                                .fill(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get brief description based on tool
    private func getToolDescription() -> String {
        switch tool.id {
        case "remove_object":
            return "Erase unwanted objects seamlessly from your photos"
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
            return "Professional headshots for LinkedIn profiles"
        case "passport_photo":
            return "Passport-ready photos instantly"
        case "twitter_avatar":
            return "Eye-catching social media avatars"
        case "image_upscaler":
            return "Enhance resolution up to 4x quality"
        case "historical_photo_restore":
            return "Restore old & damaged photographs"
        default:
            return "Transform your images with AI-powered tools"
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: DesignTokens.Spacing.lg) {
        // Main Tools Featured Tool
        FeaturedToolCard(
            tool: Tool(
                id: "remove_object",
                title: "Remove Object from Image",
                imageURL: nil as URL?,
                category: "main_tools",
                requiresPro: false,
                modelName: "lama-cleaner",
                placeholderIcon: "eraser.fill",
                prompt: "Remove the selected object naturally"
            ),
            onUseTool: {
                print("Use Tool tapped")
            },
            onLearnMore: {
                print("Learn More tapped")
            }
        )
        
        // Pro Looks Featured Tool
        FeaturedToolCard(
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
            onUseTool: {
                print("Use Tool tapped")
            },
            onLearnMore: {
                print("Learn More tapped")
            }
        )
    }
    .padding()
    .background(DesignTokens.Background.primary(.light))
    .environmentObject(ThemeManager())
}
