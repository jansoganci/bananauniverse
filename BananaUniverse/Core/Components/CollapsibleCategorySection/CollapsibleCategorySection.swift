//
//  CollapsibleCategorySection.swift
//  BananaUniverse
//
//  Created by AI Assistant on 01.11.2025.
//  Expandable category section with spring animations
//

import SwiftUI

// MARK: - Collapsible Category Section Component
struct CollapsibleCategorySection: View {
    // MARK: - Properties
    let categoryId: String
    let categoryName: String
    let tools: [Tool]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onToolTap: (Tool) -> Void
    let searchQuery: String?
    
    // MARK: - Environment
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header Button
            Button(action: {
                // Add haptic feedback for section toggle
                DesignTokens.Haptics.selectionChanged()
                onToggle()
            }) {
                HStack {
                    Text(categoryName)
                        .font(DesignTokens.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                        .fill(DesignTokens.Surface.secondary(themeManager.resolvedColorScheme).opacity(0.3))
                )
                .contentShape(Rectangle()) // Makes entire area tappable
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expandable Content
            if isExpanded {
                VStack(spacing: 0) {
                    // Tools Grid
                    ToolGridSection(
                        tools: filteredTools,
                        onToolTap: onToolTap,
                        category: categoryId
                    )
                    .padding(.top, DesignTokens.Spacing.sm)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Tools filtered by search query if provided
    private var filteredTools: [Tool] {
        guard let searchQuery = searchQuery, !searchQuery.isEmpty else {
            return tools
        }
        
        return tools.filter { tool in
            String(describing: tool.name).localizedCaseInsensitiveContains(searchQuery)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: DesignTokens.Spacing.lg) {
        // Expanded section
        CollapsibleCategorySection(
            categoryId: "main_tools",
            categoryName: "Photo Editor",
            tools: Array(Theme.mockThemes.prefix(6)),
            isExpanded: true,
            onToggle: {},
            onToolTap: { _ in },
            searchQuery: nil
        )
        
        // Collapsed section
        CollapsibleCategorySection(
            categoryId: "pro_looks",
            categoryName: "Pro Photos",
            tools: Array(Theme.mockThemes.prefix(4)),
            isExpanded: false,
            onToggle: {},
            onToolTap: { _ in },
            searchQuery: nil
        )
        
        // Section with search filter
        CollapsibleCategorySection(
            categoryId: "restoration",
            categoryName: "Enhancer",
            tools: Theme.mockThemes,
            isExpanded: true,
            onToggle: {},
            onToolTap: { _ in },
            searchQuery: "upscale"
        )
    }
    .padding()
    .background(DesignTokens.Background.primary(.light))
    .environmentObject(ThemeManager())
}