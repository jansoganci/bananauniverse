//
//  CategoryRow.swift
//  BananaUniverse
//
//  Created by AI Assistant on 02.11.2025.
//  Horizontal scrollable category row with tool cards (Amazon/Netflix style)
//

import SwiftUI

// MARK: - Category Row Component (Horizontal Scroll)
struct CategoryRow: View {
    // MARK: - Properties
    let title: String
    let tools: [Tool]
    let onToolTap: (Tool) -> Void
    let onSeeAllTap: (() -> Void)?
    let searchQuery: String?
    
    // MARK: - Environment
    @EnvironmentObject var themeManager: ThemeManager
    
    // MARK: - Initializer
    init(
        title: String,
        tools: [Tool],
        onToolTap: @escaping (Tool) -> Void,
        onSeeAllTap: (() -> Void)? = nil,
        searchQuery: String? = nil
    ) {
        self.title = title
        self.tools = tools
        self.onToolTap = onToolTap
        self.onSeeAllTap = onSeeAllTap
        self.searchQuery = searchQuery
    }
    
    // MARK: - Body
    var body: some View {
        // Hide category row if filtered tools are empty (when searching)
        if !filteredTools.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Category Title with "See All" Button
                HStack {
                    Text(title)
                        .font(DesignTokens.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                    
                    Spacer()
                    
                    // "See All" Button (only show if callback is provided)
                    if let onSeeAllTap = onSeeAllTap {
                        Button(action: {
                            DesignTokens.Haptics.selectionChanged()
                            onSeeAllTap()
                        }) {
                            HStack(spacing: DesignTokens.Spacing.xs) {
                                Text("See All")
                                    .font(DesignTokens.Typography.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(DesignTokens.Brand.primary(themeManager.resolvedColorScheme))
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                
                // Horizontal Scrollable Tools
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(filteredTools) { tool in
                            ToolCard(
                                tool: tool,
                                onTap: {
                                    onToolTap(tool)
                                }
                            )
                            .frame(width: 160)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
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
            String(describing: tool.title).localizedCaseInsensitiveContains(searchQuery) ||
            tool.id.localizedCaseInsensitiveContains(searchQuery) ||
            tool.prompt.localizedCaseInsensitiveContains(searchQuery) ||
            tool.category.localizedCaseInsensitiveContains(searchQuery)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: DesignTokens.Spacing.xl) {
        // Category row without search
        CategoryRow(
            title: "Photo Editor",
            tools: Array(Tool.mainTools.prefix(5)),
            onToolTap: { _ in },
            onSeeAllTap: { print("See All tapped") }
        )
        
        // Category row with search filter
        CategoryRow(
            title: "Seasonal",
            tools: Tool.seasonalTools,
            onToolTap: { _ in },
            searchQuery: "winter"
        )
        
        // Category row without "See All" button
        CategoryRow(
            title: "Pro Photos",
            tools: Array(Tool.proLooksTools.prefix(4)),
            onToolTap: { _ in }
        )
    }
    .padding()
    .background(DesignTokens.Background.primary(.light))
    .environmentObject(ThemeManager())
}

#Preview("Dark Mode") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        CategoryRow(
            title: "Enhancer",
            tools: Tool.restorationTools,
            onToolTap: { _ in },
            onSeeAllTap: { print("See All tapped") }
        )
    }
    .padding()
    .background(DesignTokens.Background.primary(.dark))
    .environmentObject(ThemeManager())
    .preferredColorScheme(.dark)
}

