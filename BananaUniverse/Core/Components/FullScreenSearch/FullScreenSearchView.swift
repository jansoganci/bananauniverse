//
//  FullScreenSearchView.swift
//  BananaUniverse
//
//  Created by AI Assistant on 2026-01-27.
//  Full-screen search overlay with recent searches, popular tools, and results
//

import SwiftUI

struct FullScreenSearchView: View {
    @Binding var searchQuery: String
    let tools: [Tool]
    let onToolSelected: (Tool) -> Void
    let onDismiss: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isSearchFocused: Bool
    
    @State private var localSearchQuery: String = ""
    @State private var searchTimer: Timer?
    @State private var recentSearches: [String] = []
    
    private let searchHistoryService = SearchHistoryService.shared
    
    var body: some View {
        ZStack {
            // Blur background overlay
            DesignTokens.Background.primary(colorScheme)
                .opacity(0.95)
                .ignoresSafeArea()
                .blur(radius: 20)
            
            VStack(spacing: 0) {
                // Search Header
                searchHeader
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.top, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.sm)
                
                // Content Area
                ScrollView {
                    if localSearchQuery.isEmpty {
                        // Recent Searches & Popular Tools
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                            if !recentSearches.isEmpty {
                                recentSearchesSection
                            }
                            
                            popularToolsSection
                        }
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.top, DesignTokens.Spacing.md)
                    } else {
                        // Search Results
                        searchResultsSection
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.top, DesignTokens.Spacing.md)
                    }
                }
            }
        }
        .onAppear {
            // Load recent searches
            recentSearches = searchHistoryService.getRecentSearches()
            
            // Auto-focus search field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onDisappear {
            searchTimer?.invalidate()
            searchTimer = nil
        }
    }
    
    // MARK: - Search Header
    
    private var searchHeader: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Cancel Button
            Button(action: onDismiss) {
                Text("core_cancel".localized)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Text.accent(colorScheme))
            }
            .accessibilityLabel("accessibility_cancel_search".localized)
            .accessibilityHint("accessibility_double_tap_close".localized)
            
            // Search TextField
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                
                TextField("search_placeholder".localized, text: $localSearchQuery)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Text.primary(colorScheme))
                    .focused($isSearchFocused)
                    .onChange(of: localSearchQuery) { newValue in
                        searchTimer?.invalidate()
                        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                            let sanitized = sanitizeSearch(newValue)
                            searchQuery = sanitized
                            
                            // Add to search history if not empty
                            if !sanitized.isEmpty {
                                searchHistoryService.addSearch(sanitized)
                                recentSearches = searchHistoryService.getRecentSearches()
                            }
                        }
                    }
                    .accessibilityLabel("accessibility_search_tools".localized)
                    .accessibilityHint("accessibility_double_tap_search".localized)
                
                if !localSearchQuery.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            localSearchQuery = ""
                            searchQuery = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                            .font(.system(size: 16))
                    }
                    .accessibilityLabel("accessibility_clear_search".localized)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .fill(DesignTokens.Surface.input(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(DesignTokens.Special.borderDefault(colorScheme), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Recent Searches Section
    
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("core_recent_searches".localized)
                .font(DesignTokens.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                .padding(.horizontal, DesignTokens.Spacing.md)
            
            VStack(spacing: 0) {
                ForEach(Array(recentSearches.prefix(5).enumerated()), id: \.element) { index, query in
                    RecentSearchRow(query: query) {
                        localSearchQuery = query
                        searchQuery = sanitizeSearch(query)
                        searchHistoryService.addSearch(query)
                    }
                    
                    if index < min(4, recentSearches.count - 1) {
                        Divider()
                            .padding(.leading, DesignTokens.Spacing.xl + DesignTokens.Spacing.md)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .fill(DesignTokens.Surface.secondary(colorScheme))
            )
        }
    }
    
    // MARK: - Popular Tools Section
    
    private var popularToolsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("core_popular_tools".localized)
                .font(DesignTokens.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                .padding(.horizontal, DesignTokens.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(Array(popularTools.prefix(5))) { tool in
                        ToolCard(
                            tool: tool,
                            onTap: {
                                searchHistoryService.addSearch(tool.name)
                                onToolSelected(tool)
                            }
                        )
                        .frame(width: 160)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
        }
    }
    
    // MARK: - Search Results Section
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if !filteredResults.isEmpty {
                Text(String(format: "search_results_for".localized, localSearchQuery))
                    .font(DesignTokens.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                    .padding(.horizontal, DesignTokens.Spacing.md)
                
                VStack(spacing: 0) {
                    ForEach(Array(filteredResults.enumerated()), id: \.element.id) { index, tool in
                        SearchResultRow(tool: tool) {
                            searchHistoryService.addSearch(tool.name)
                            onToolSelected(tool)
                        }
                        
                        if index < filteredResults.count - 1 {
                            Divider()
                                .padding(.leading, DesignTokens.Spacing.xl + DesignTokens.Spacing.md)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .fill(DesignTokens.Surface.secondary(colorScheme))
                )
            } else {
                // Empty state
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                        .padding(.top, 60)
                    
                    Text("core_no_tools_found".localized)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(DesignTokens.Text.primary(colorScheme))
                    
                    Text("core_try_different_search".localized)
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.Text.secondary(colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var popularTools: [Tool] {
        tools.filter { $0.isFeatured }.prefix(5).map { $0 }
    }
    
    private var filteredResults: [Tool] {
        guard !searchQuery.isEmpty else { return [] }
        
        return tools.filter { tool in
            tool.name.localizedCaseInsensitiveContains(searchQuery) ||
            tool.prompt.localizedCaseInsensitiveContains(searchQuery) ||
            tool.category.localizedCaseInsensitiveContains(searchQuery) ||
            (tool.description?.localizedCaseInsensitiveContains(searchQuery) ?? false) ||
            (tool.shortDescription?.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
    }
    
    // MARK: - Helper Methods
    
    private func sanitizeSearch(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let capped = String(trimmed.prefix(100))
        // allow alphanumeric, space, dot, dash, underscore
        return capped.filter { $0.isLetter || $0.isNumber || " .-_".contains($0) }
    }
}

#Preview {
    FullScreenSearchView(
        searchQuery: .constant(""),
        tools: [
            Theme(
                id: "remove_object",
                name: "Remove Object",
                description: "Remove unwanted objects",
                shortDescription: "Remove objects",
                thumbnailURL: nil,
                category: "main_tools",
                modelName: "lama",
                placeholderIcon: "eraser.fill",
                prompt: "Remove object",
                isFeatured: true,
                isAvailable: true,
                requiresPro: false,
                defaultSettings: nil,
                createdAt: Date()
            )
        ],
        onToolSelected: { _ in },
        onDismiss: {}
    )
    .environmentObject(ThemeManager())
}
