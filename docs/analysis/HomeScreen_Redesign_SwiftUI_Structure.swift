//
//  HomeScreen_Redesign_SwiftUI_Structure.swift
//  BananaUniverse
//
//  Pseudocode/Structure Example for Home Screen UX Redesign
//  This is a reference implementation showing the proposed layout structure
//  DO NOT import - this is documentation only
//

import SwiftUI

// MARK: - Proposed HomeView Structure (Pseudocode)

struct HomeView_Redesigned: View {
    // Existing state (unchanged)
    @State private var showPaywall = false
    @StateObject private var authService = HybridAuthService.shared
    @StateObject private var creditManager = HybridCreditManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    let onToolSelected: (Tool) -> Void
    
    @State private var rawSearch: String = ""
    @State private var searchQuery: String = ""
    @State private var searchTimer: Timer?
    
    // NEW: Expanded categories set (can expand multiple simultaneously)
    @State private var expandedCategories: Set<String> = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 1. Header (unchanged)
                UnifiedHeaderBar(
                    title: "",
                    leftContent: .appLogo(32),
                    rightContent: creditManager.isPremiumUser 
                        ? .unlimitedBadge({})
                        : .getProButton({ showPaywall = true })
                )
                
                // 2. Quota Warning (unchanged)
                if !creditManager.isPremiumUser && creditManager.remainingQuota <= 1 {
                    QuotaWarningBanner()
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.top, DesignTokens.Spacing.sm)
                }
                
                // 3. Search Bar (unchanged)
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                    
                    TextField("Search tools…", text: $rawSearch)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(size: 16))
                        .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                        .onChange(of: rawSearch) { newValue in
                            // Existing debounce logic
                            searchTimer?.invalidate()
                            searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                                self.searchQuery = sanitizeSearch(newValue)
                            }
                        }
                    
                    if !rawSearch.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                rawSearch = ""
                                searchQuery = ""
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignTokens.Background.secondary(themeManager.resolvedColorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignTokens.Text.secondary(themeManager.resolvedColorScheme).opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                
                // 4. Content Area (REDESIGNED)
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        // 4a. Featured Carousel (unchanged, only show when not searching)
                        if searchQuery.isEmpty && !featuredCarouselTools.isEmpty {
                            FeaturedCarouselView(
                                tools: featuredCarouselTools,
                                onToolTap: handleToolTap
                            )
                            .transition(.opacity)
                        }
                        
                        // 4b. NEW: Category Cards Section
                        if searchQuery.isEmpty {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                                // Section Header
                                Text("All Categories")
                                    .font(DesignTokens.Typography.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                                    .padding(.horizontal, DesignTokens.Spacing.md)
                                
                                // Category Cards Grid (2×2)
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: DesignTokens.Spacing.md),
                                        GridItem(.flexible(), spacing: DesignTokens.Spacing.md)
                                    ],
                                    spacing: DesignTokens.Spacing.md
                                ) {
                                    ForEach(categories, id: \.id) { category in
                                        CategoryCard(
                                            categoryId: category.id,
                                            categoryName: category.name,
                                            toolCount: CategoryFeaturedMapping.remainingTools(for: category.id).count,
                                            icon: categoryIcon(category.id),
                                            isExpanded: expandedCategories.contains(category.id),
                                            onTap: {
                                                withAnimation(DesignTokens.Animation.spring) {
                                                    toggleCategory(category.id)
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, DesignTokens.Spacing.md)
                            }
                            .padding(.top, DesignTokens.Spacing.lg)
                        }
                        
                        // 4c. Expanded Category Tools (show when category expanded)
                        if searchQuery.isEmpty {
                            ForEach(categories.filter { expandedCategories.contains($0.id) }, id: \.id) { category in
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                    // Category Section Header
                                    HStack {
                                        Text(category.name)
                                            .font(DesignTokens.Typography.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                                        
                                        Spacer()
                                        
                                        Button {
                                            withAnimation(DesignTokens.Animation.spring) {
                                                expandedCategories.remove(category.id)
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                                                .font(.system(size: 20))
                                        }
                                    }
                                    .padding(.horizontal, DesignTokens.Spacing.md)
                                    
                                    // Tools Grid
                                    ToolGridSection(
                                        tools: CategoryFeaturedMapping.remainingTools(for: category.id),
                                        onToolTap: handleToolTap,
                                        category: category.id
                                    )
                                }
                                .padding(.top, DesignTokens.Spacing.md)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .move(edge: .top))
                                ))
                            }
                        }
                        
                        // 4d. Search Results (when searching)
                        if !searchQuery.isEmpty {
                            // Filter and show matching tools across all categories
                            ForEach(categories, id: \.id) { category in
                                let filteredTools = CategoryFeaturedMapping.remainingTools(for: category.id)
                                    .filter { tool in
                                        tool.title.localizedCaseInsensitiveContains(searchQuery) ||
                                        tool.prompt.localizedCaseInsensitiveContains(searchQuery)
                                    }
                                
                                if !filteredTools.isEmpty {
                                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                        Text(category.name)
                                            .font(DesignTokens.Typography.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                                            .padding(.horizontal, DesignTokens.Spacing.md)
                                        
                                        ToolGridSection(
                                            tools: filteredTools,
                                            onToolTap: handleToolTap,
                                            category: category.id
                                        )
                                    }
                                    .padding(.top, DesignTokens.Spacing.md)
                                }
                            }
                        }
                        
                        // 4e. Empty State (unchanged)
                        if !searchQuery.isEmpty && !hasSearchResults {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                                    .padding(.top, 60)
                                
                                Text("No tools found")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                                
                                Text("Try a different search term")
                                    .font(.system(size: 14))
                                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                            .transition(.opacity)
                        }
                    }
                    .padding(.bottom, DesignTokens.Spacing.lg)
                }
            }
            .background(DesignTokens.Background.primary(themeManager.resolvedColorScheme))
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showPaywall) {
            PreviewPaywallView()
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleCategory(_ categoryId: String) {
        DesignTokens.Haptics.selectionChanged()
        
        if expandedCategories.contains(categoryId) {
            expandedCategories.remove(categoryId)
        } else {
            expandedCategories.insert(categoryId)
        }
    }
    
    private func categoryIcon(_ categoryId: String) -> String {
        switch categoryId {
        case "main_tools": return "photo"
        case "seasonal": return "calendar"
        case "pro_looks": return "sparkles"
        case "restoration": return "wand.and.stars"
        default: return "square.grid.2x2"
        }
    }
    
    // Existing computed properties and methods remain unchanged
    private var featuredCarouselTools: [Tool] { /* ... */ }
    private var categories: [(id: String, name: String)] { /* ... */ }
    private func handleToolTap(_ tool: Tool) { /* ... */ }
    private func sanitizeSearch(_ input: String) -> String { /* ... */ }
    private func updateSearchResults() { /* ... */ }
}

// MARK: - NEW: Category Card Component

struct CategoryCard: View {
    let categoryId: String
    let categoryName: String
    let toolCount: Int
    let icon: String
    let isExpanded: Bool
    let onTap: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(DesignTokens.Brand.primary(.light))
                    .frame(height: 40)
                
                // Category Name
                Text(categoryName)
                    .font(DesignTokens.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignTokens.Text.primary(themeManager.resolvedColorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Tool Count
                Text("\(toolCount) tools")
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Text.secondary(themeManager.resolvedColorScheme))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .fill(DesignTokens.Surface.secondary(themeManager.resolvedColorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(
                        isExpanded 
                            ? DesignTokens.Brand.primary(.light).opacity(0.5)
                            : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: DesignTokens.Shadow.md.color,
                radius: DesignTokens.Shadow.md.radius,
                x: DesignTokens.Shadow.md.x,
                y: DesignTokens.Shadow.md.y
            )
            .scaleEffect(isExpanded ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Visual Hierarchy Summary

/*
 VISUAL LAYOUT STRUCTURE:
 
 ┌─────────────────────────────────────┐
 │ Logo              PRO Badge          │ ← Header (56pt)
 ├─────────────────────────────────────┤
 │ ⚠️ Quota Warning (conditional)       │ ← Banner (if needed)
 ├─────────────────────────────────────┤
 │ 🔍 Search tools...                  │ ← Search Bar (56pt)
 ├─────────────────────────────────────┤
 │ [Featured Carousel - 5 tools]       │ ← Carousel (~200pt, optional)
 ├─────────────────────────────────────┤
 │                                     │
 │ All Categories                      │ ← Section Title (24pt)
 │ ┌───────────┬───────────┐          │
 │ │ 📷 Photo  │ 🎨 Seasonal│          │ ← Category Cards
 │ │ Editor    │            │          │   (2×2 grid)
 │ │ 12 tools  │ 8 tools    │          │   (120pt height each)
 │ ├───────────┼───────────┤          │
 │ │ ✨ Pro    │ 🔧 Enhancer│          │
 │ │ Photos    │            │          │
 │ │ 6 tools   │ 4 tools    │          │
 │ └───────────┴───────────┘          │
 │                                     │
 │ ┌─────────────────────────────────┐ │ ← Expanded Category
 │ │ Photo Editor          ✕         │ │   (when tapped)
 │ ├─────────────────────────────────┤ │
 │ │  Tool  Tool                     │ │   Tools Grid
 │ │  Tool  Tool                     │ │   (2 columns)
 │ │  Tool  Tool                     │ │
 │ └─────────────────────────────────┘ │
 │                                     │
 └─────────────────────────────────────┘
 
 TOTAL INITIAL HEIGHT (without expansion):
 - Header: 56pt
 - Search: 56pt
 - Carousel: ~200pt (optional)
 - Section Title: 24pt
 - Category Grid: 248pt (2×2 cards at 120pt + spacing)
 - Bottom Padding: 24pt
 = ~608pt (fits on iPhone 14 Pro Max: 932pt screen height)
 
 WITH EXPANSION:
 - Additional space for tools grid (dynamic)
 - Smooth scroll to expanded content
 */

